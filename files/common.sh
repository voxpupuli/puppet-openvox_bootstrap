#! /usr/bin/env bash

# PT_* variables are set by Bolt.
declare PT__installdir

tempdir=$(mktemp -d)
trap 'rm -rf $tempdir' EXIT

log() {
  local _level="$1"
  shift

  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S')

  echo "${ts} [${_level}]: $*"
}

info() {
  log 'INFO' "$*"
}

err() {
  log 'ERROR' "$*"
}

fail() {
  err "$*"
  exit 1
}

# Log the value of a variable.
assigned() {
  local _var="$1"

  info "Assigned ${_var}=${!_var}"
}

# Check if a command exists.
exists() {
  command -v "$1" > /dev/null 2>&1
}

# Log and execute a command in a subshell, capturing and echoing its
# output before returning its exit status.
#
# Also captures output and status in the global variables:
#
# LAST_EXEC_AND_CAPTURE_OUTPUT
# LAST_EXEC_AND_CAPTURE_STATUS
#
# so that the caller can inspect them as well.
exec_and_capture() {
  info "Executing: $*"

  local _restore_errexit=false
  if [[ "$-" == *e* ]]; then
    _restore_errexit=true
  fi

  set +e
  LAST_EXEC_AND_CAPTURE_OUTPUT=$("$@" 2>&1)
  LAST_EXEC_AND_CAPTURE_STATUS=$?
  if ${_restore_errexit}; then
    set -e
  fi

  echo "${LAST_EXEC_AND_CAPTURE_OUTPUT}"
  info "Status: ${LAST_EXEC_AND_CAPTURE_STATUS}"
  return $LAST_EXEC_AND_CAPTURE_STATUS
}

# Download the given url to the given local file path.
download() {
  local _url="$1"
  local _file="$2"

  if exists 'wget'; then
    exec_and_capture wget -O "${_file}" "${_url}"
  elif exists 'curl'; then
    exec_and_capture curl --fail -sSL -o "${_file}" "${_url}"
  else
    fail "Unable to download ${_url}. Neither wget nor curl are installed."
  fi
}

# Debian pre-release builds do not contain their version number
# in /etc/os-release. They do contain codename. Openvox packages
# are named with the version number. Hence this lookup, that
# unfotunately needs to be updated with each new Debian release...
translate_codename_to_version() {
  local _codename="$1"

  case "${_codename}" in
    trixie)
      echo '13'
      ;;
    forky)
      echo '14'
      ;;
    *)
      # VERSION_ID is set to 'n/a' in /etc/os-release, so
      # if we don't know the codename, let's return the same value.
      echo 'n/a'
      ;;
  esac
}

# Set the $os_family variable based on the platform.
set_os_family() {
  local _platform="${1:-${platform}}"

  # Downcase the platform so as to avoid case issues.
  case ${_platform,,} in
    amazon)
      os_family='amazon'
      ;;
    rhel|redhat|centos|scientific|oraclelinux|rocky|almalinux)
      os_family='el'
      ;;
    fedora)
      os_family='fedora'
      ;;
    sles|suse)
      os_family='sles'
      ;;
    debian)
      os_family='debian'
      ;;
    ubuntu)
      os_family='ubuntu'
      ;;
    *)
      fail "Unhandled platform: '${_platform}'"
      ;;
  esac
  export os_family # quiets shellcheck SC2034
  assigned 'os_family'
}

# Read local OS facts by reaching out to the puppetlabs-facts bash
# task as an executable, then set these globals:
#   $platform
#   $os_full_version
#   $os_major_version
#   $os_family
set_platform_globals() {
  local facts="${PT__installdir}/facts/tasks/bash.sh"
  if [ -e "${facts}" ]; then
    platform=$(bash "${facts}" platform)
    os_full_version=$(bash "${facts}" release)
    if [[ "${os_full_version}" == "n/a" ]]; then
      # Hit the facts json with blunt objects until the codename value
      # pops out...
      codename=$(bash "${facts}" | grep '"codename"' | cut -d':' -f2 | grep -oE '[^ "]+')
      os_full_version=$(translate_codename_to_version "${codename}")
    fi
    os_major_version=${os_full_version%%.*}
  else
    fail "Unable to find the puppetlabs-facts bash task to determine platform at '${facts}'."
  fi
  export platform # quiets shellcheck SC2034
  assigned 'platform'
  export os_full_version # quiets shellcheck SC2034
  assigned 'os_full_version'
  export os_major_version # quiets shellcheck SC2034
  assigned 'os_major_version'

  set_os_family "${platform}"
}

# Based on platform os_family set:
#  package_type - rpm or deb or...
#  package_file_suffix - the file extension for the release package name
set_package_type() {
  local _os_family="${1:-${os_family}}"

  if [[ -z "${_os_family}" ]]; then
    set_platform_globals
    _os_family="${os_family}"
  fi

  case $_os_family in
    amazon|fedora|el|sles)
      package_type='rpm'
      package_file_suffix='noarch.rpm'
      ;;
    debian|ubuntu)
      package_type='deb'
      package_file_suffix='deb'
      ;;
  esac
  export package_type # quiets shellcheck SC2034
  assigned 'package_type'
  export package_file_suffix # quiets shellcheck SC2034
  assigned 'package_file_suffix'
}

# Construct and echo the full debian package version string.
# Echoing for $() capture rather than setting a 'global' $var
# since this could be called multiple times for different packages.
get_deb_package_version() {
  local _version="$1"
  local _os_family="${2:-${os_family}}"
  local _os_full_version="${3-${os_full_version}}"

  # Need the full packaging version for deb.
  # As an example, for openvox-agent 8.14.0 on ubuntu 24.04:
  # 8.14.0-1+ubuntu24.04
  if [[ "${_version}" =~ - ]]; then
    # Caller's version already has a '-' seprator, so we
    # should respect that they have probably supplied some
    # full package version string.
    _package_version="${_version}"
  else
    _package_version="${_version}-1+${_os_family}${_os_full_version}"
  fi

  echo -n "${_package_version}"
}

# Install an rpm package, either from a local file or from the
# repository using the best available package manager interface.
#
# In descending preference, checks for dnf, yum and zypper.
#
# Downgrades are implicitly accepted when dnf/yum are used and a
# version is specified. I'm not certain about zypper's behavior yet.
install_rpm() {
  if exists 'dnf'; then
    exec_and_capture dnf install --assumeyes "$@"
  elif exists 'yum'; then
    exec_and_capture yum install --assumeyes "$@"
  elif exists 'zypper'; then
    exec_and_capture zypper install --non-interactive "$@"
  else
    fail "Unable to install $*. Neither dnf, yum nor zypper are installed."
  fi
}

# Install a deb package, either from a local file or from the
# repository using the best available package manager interface.
#
# Prefers apt-get to apt, since apt is really meant for interactive
# use.
install_deb() {
  if exists 'apt-get'; then
    exec_and_capture apt-get install --yes "$@"
  elif exists 'apt'; then
    exec_and_capture apt install --yes "$@"
  else
    fail "Unable to install $*. Neither apt nor apt-get are installed."
  fi
}

# Install a local rpm or deb package file.
install_package_file() {
  local _package_file="$1"
  # If not set, use the file extension of the package file.
  local _package_type="${2:-${_package_file##*.}}"

  info "Installing release package '${_package_file}' of type '${_package_type}'"
  case $_package_type in
    rpm)
      # can switch to dnf when we drop amazon 2 support
      install_rpm "$_package_file"
      ;;
    deb)
      # Specifying --allow-downgrades here avoids an irritating bug
      # with apt where the openvox-agent pins in the openvox release
      # package seemingly cause a repeat call of `apt-get install
      # ./local.rpm` to fail due to apt considering it a downgrade
      # despite the version being identical. This was a problem for
      # idempotency of install_build_artifact task calls when the
      # release package was also installed.
      install_deb --allow-downgrades "$_package_file"
      ;;
    *)
      fail "Unhandled package type: '${package_type}'"
      ;;
  esac
}

# Install a package using the system package manager.
# The version is optional, and if not provided, the latest version
# available in the repository will be installed.
install_package() {
  local _package="$1"
  local _version="$2"
  local _os_family="${3:-${os_family}}"
  local _os_full_version="${4:-${os_full_version}}"

  info "Installing ${_package} ${_version}"

  if [[ -z "${_os_family}" ]] || [[ -z "${_os_full_version}" ]]; then
    set_platform_globals
    _os_family="${os_family}"
    _os_full_version="${os_full_version}"
  fi

  local _allow_downgrades
  local _package_and_version
  if [[ -n "${_version}" ]] && [[ "${_version}" != 'latest' ]]; then
    case $_os_family in
      debian|ubuntu)
        # dnf/yum implicitly allow downgrades when a version is
        # specified, but apt/apt-get do not, so we need to explicitly
        # specify that here.
        _allow_downgrades='--allow-downgrades'
        local _deb_package_version
        _deb_package_version=$(get_deb_package_version "${_version}" "${_os_family}" "${_os_full_version}")
        _package_and_version="${_package}=${_deb_package_version}"
        ;;
      *)
        _package_and_version="${_package}-${_version}"
        ;;
    esac
  else
    _package_and_version="${_package}"
  fi

  case ${_os_family} in
    debian|ubuntu)
      # _allow_downgrades is unquoted here because it is either an
      # empty string or the string '--allow-downgrades', and
      # Shellcheck seems smart enough to recognize that this is ok.
      # Leaving it unquoted prevents it from being passed as an empty
      # argument when it is an empty string, and avoids an extra space
      # when $* is evaluated.
      install_deb ${_allow_downgrades} "${_package_and_version}"
      ;;
    *)
      install_rpm "${_package_and_version}"
      ;;
  esac
}

# Update the package manager cache.
refresh_package_cache() {
  if exists 'apt-get'; then
    exec_and_capture apt-get update
  elif exists 'apt'; then
    exec_and_capture apt update
  elif exists 'dnf'; then
    exec_and_capture dnf clean all
  elif exists 'yum'; then
    exec_and_capture yum clean all
  elif exists 'zypper'; then
    exec_and_capture zypper refresh
  else
    echo "No package manager found."
    exit 1
  fi
}

# Test whether the given package name matches a list of
# openvox packages that are noarch.
noarch_package() {
  local _package="$1"

  # List of noarch packages.
  local noarch_packages=(
    'openvox-server'
    'openvoxdb'
    'openvoxdb-termini'
  )

  for pkg in "${noarch_packages[@]}"; do
    if [[ "${_package}" == "${pkg}" ]]; then
      return 0
    fi
  done

  return 1
}

# Lookup the cpu architecture and set it as cpu_arch.
# Translates x86_64 to amd64 and aarch64 to arm64 for debian/ubuntu.
set_cpu_architecture() {
  local _family="$1"

  local _arch
  _arch=$(uname -m)
  case "${_family}" in
    debian|ubuntu)
      case "${_arch}" in
        x86_64)
          cpu_arch="amd64"
          ;;
        aarch64)
          cpu_arch="arm64"
          ;;
        *)
          cpu_arch="${_arch}"
          ;;
      esac
      ;;
    *)
      cpu_arch="${_arch}"
      ;;
  esac
  export cpu_arch # quiets shellcheck SC2034
  assigned 'cpu_arch'
}

# Lookup the architecture for the given package and set it as
# package_arch.
#
# This will either be noarch/all depending on the platform and
# whether the package name matches an openvox noarch_package(),
# or it will be the cpu_arch.
set_package_architecture() {
  local _package="$1"
  local _os_family="${2:-${os_family}}"

  if noarch_package "${_package}"; then
    case "${_os_family}" in
      debian|ubuntu)
        package_arch='all'
      ;;
      *)
        package_arch='noarch'
      ;;
    esac
  else
    set_cpu_architecture "${_os_family}"
    package_arch="${cpu_arch}"
  fi
  export package_arch # quiets shellcheck SC2034
  assigned 'package_arch'
}

# Based on platform, package and version set:
#   package_name - the name of the build artifact package
#   package_url - the url to download the build artifact package
#
# Currently this is based on the structure of the package repository
# at https://artifacts.voxpupuli.org, which is a page
# that provides a summary of links to artifacts contained in an S3
# bucket hosted by Oregon State University Open Source Lab.
#
# Example rpm:
# https://artifacts.voxpupuli.org/openvox-agent/8.15.0/openvox-agent-8.15.0-1.el8.x86_64.rpm
# Example deb:
# https://artifacts.voxpupuli.org/openvox-agent/8.15.0/openvox-agent_8.15.0-1%2Bdebian12_amd64.deb
set_artifacts_package_url() {
  local _artifacts_source="$1"
  local _package="$2"
  local _version="$3"

  # When installing a snapshot build of an ezbake project,
  # the release number is not included in the file name where it is
  # on tagged versions.
  local _release="-1"
  if [[ "${_version}" =~ "SNAPSHOT" ]];then
          _release=""
  fi

  set_package_type "${os_family}"
  set_package_architecture "${_package}" "${os_family}"

  case "${package_type}" in
    rpm)
      # Account for a fedora naming quirk in the build artifacts.
      if [[ "${os_family}" == "fedora" ]]; then
        _os_family="fc"
      else
        _os_family="${os_family}"
      fi
      package_name="${_package}-${_version}${_release}.${_os_family}${os_major_version}.${package_arch}.${package_type}"
      ;;
    deb)
      package_name="${_package}_${_version}${_release}%2B${os_family}${os_full_version}_${package_arch}.${package_type}"
      ;;
    *)
      fail "Unhandled package type: '${package_type}'"
      ;;
  esac

  case "${_package}" in
    openvoxdb-termini)
      local _package_dir='openvoxdb'
      ;;
    *)
      local _package_dir="${_package}"
      ;;
  esac

  package_url="${_artifacts_source}/${_package_dir}/${_version}/${package_name}"

  export package_name # quiets shellcheck SC2034
  assigned 'package_name'
  export package_url # quiets shellcheck SC2034
  assigned 'package_url'
}

# Stop and disable the service for the given package.
#
# Only intended to work for openvox-agent, openvoxdb and
# openvox-server.
#
# Will fail if openvox isn't installed.
#
# (voxpupuli/puppet-openvox_bootstrap#35)
# Implemented for integration with openbolt.
stop_and_disable_service() {
  local _package="$1"
  # Using the full path here because openvox is installed into opt,
  # and if we've just installed, the shell's PATH will not include it
  # yet.
  local _puppet="${2:-/opt/puppetlabs/bin/puppet}"

  case "${_package}" in
    openvox-agent)
      local _service='puppet'
      ;;
    openvoxdb)
      local _service='puppetdb'
      ;;
    openvox-server)
      local _service='puppetserver'
      ;;
    *)
      fail "Cannot stop service. Unknown service for package: '${_package}'"
      ;;
  esac

  info "Stopping and disabling service '${_service}' for package '${_package}'"

  if [ -x "${_puppet}" ]; then
    exec_and_capture "${_puppet}" resource service "${_service}" ensure=stopped enable=false
  else
    fail "Puppet executable not found at '${_puppet}'. Cannot stop and disable service '${_service}'."
  fi
}
