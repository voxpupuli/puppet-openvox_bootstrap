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
  local _cmd="$*"

  info "Executing: ${_cmd}"

  set +e
  LAST_EXEC_AND_CAPTURE_OUTPUT=$(${_cmd} 2>&1)
  LAST_EXEC_AND_CAPTURE_STATUS=$?
  set -e

  echo "${LAST_EXEC_AND_CAPTURE_OUTPUT}"
  info "Status: ${LAST_EXEC_AND_CAPTURE_STATUS}"
  return $LAST_EXEC_AND_CAPTURE_STATUS
}

# If the passed command fails with output matching the given regex,
# retry the command after delay up to given number of retries.
#
# Aborts retries if the command fails but output does not match the
# given error regex.
#
# Returns the status of the last executed command.
#
# Args:
#  $1 - retry count
#  $2 - delay in seconds
#  $3 - regex to match against command output
#  Remaining args - command to execute
with_retries_if() {
  local _retries="$1"
  local _delay="$2"
  local _error_regex="$3"
  shift 3

  local _cmd="$*"
  local _result
  local _status

  for ((i = 1; i <= _retries; i++)); do
    if [[ $i -gt 1 ]]; then
      info "Retrying in ${_delay} seconds..."
      sleep "${_delay}"
    fi

    info "Attempt ${i} of $_retries: ${_cmd}"

    if exec_and_capture "${_cmd}"; then
      _status=$LAST_EXEC_AND_CAPTURE_STATUS
      break # command succeeded
    else
      _result="${LAST_EXEC_AND_CAPTURE_OUTPUT}"
      _status=$LAST_EXEC_AND_CAPTURE_STATUS
      if ! [[ "${_result}" =~ ${_error_regex} ]]; then
        info "Command failed but output did not match /${_error_regex}/. Aborting retries."
        break
      fi
    fi
  done

  return "${_status}"
}

# Retries an rpm command if it fails with output that matches an rpm
# lock error (rpm running in another process).
#
# All arguments given to the function are passed to the rpm command.
#
# NOTE: The higher level package managers (dnf, yum, apt, etc.)
# already manage lock waits. This function is only used for the
# specific case of manually installing the release package, which
# can collide with other uses of rpm during vm initialization, for
# example.
rpm_with_retries() {
  with_retries_if 5 5 'error.*rpm.*lock' rpm "$@"
}

# Varient of rpm_with_retries for dpkg.
#
# (I haven't seen a dpkg lock failure in CI, but the mechanism for
# failure is the same.)
dpkg_with_retries() {
  with_retries_if 5 5 'error.*dpkg.*lock' dpkg "$@"
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

# Install a local rpm or deb package file.
install_package_file() {
  local _package_file="$1"
  # If not set, use the file extension of the package file.
  local _package_type="${2:-${_package_file##*.}}"

  info "Installing release package '${_package_file}' of type '${_package_type}'"
  case $_package_type in
    rpm)
      rpm_with_retries -Uvh --replacepkgs "$_package_file"
      ;;
    deb)
      dpkg_with_retries -i "$_package_file"
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

  local _package_and_version
  if [[ -n "${_version}" ]] && [[ "${_version}" != 'latest' ]]; then
    case $_os_family in
      debian|ubuntu)
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
      if exists 'apt-get'; then
        exec_and_capture apt-get install -y "${_package_and_version}"
      elif exists 'apt'; then
        exec_and_capture apt install -y "${_package_and_version}"
      else
        fail "Unable to install ${_package}. Neither apt nor apt-get are installed."
      fi
      ;;
    *)
      if exists 'dnf'; then
        exec_and_capture dnf install -y "${_package_and_version}"
      elif exists 'yum'; then
        exec_and_capture yum install -y "${_package_and_version}"
      elif exists 'zypper'; then
        exec_and_capture zypper install -y "${_package_and_version}"
      else
        fail "Unable to install ${_package}. Neither dnf, yum nor zypper are installed."
      fi
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
      package_name="${_package}-${_version}-1.${_os_family}${os_major_version}.${package_arch}.${package_type}"
      ;;
    deb)
      package_name="${_package}_${_version}-1%2B${os_family}${os_full_version}_${package_arch}.${package_type}"
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
