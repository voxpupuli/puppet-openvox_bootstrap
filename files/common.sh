#! /usr/bin/env bash

# PT_* variables are set by Bolt.
# shellcheck disable=SC2154
installdir=$PT__installdir

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
    exec_and_capture curl -sSL -o "${_file}" "${_url}"
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

# Set platform, full_version and major_version variables by reaching
# out to the puppetlabs-facts bash task as an executable.
set_platform() {
  local facts="${installdir}/facts/tasks/bash.sh"
  if [ -e "${facts}" ]; then
    platform=$(bash "${facts}" platform)
    full_version=$(bash "${facts}" release)
    if [[ "${full_version}" == "n/a" ]]; then
      # Hit the facts json with blunt objects until the codename value
      # pops out...
      codename=$(bash "${facts}" | grep '"codename"' | cut -d':' -f2 | grep -oE '[^ "]+')
      full_version=$(translate_codename_to_version "${codename}")
    fi
    major_version=${full_version%%.*}
  else
    fail "Unable to find the puppetlabs-facts bash task to determine platform at '${facts}'."
  fi
  export platform # quiets shellcheck SC2034
  assigned 'platform'
  export full_version # quiets shellcheck SC2034
  assigned 'full_version'
  export major_version # quiets shellcheck SC2034
  assigned 'major_version'
}

# Set the OS family variable based on the platform.
set_family() {
  local _platform="${1:-${platform}}"

  if [[ -z "${_platform}" ]]; then
    set_platform
    _platform="${platform}"
  fi

  # Downcase the platform so as to avoid case issues.
  case ${_platform,,} in
    amazon)
      family='amazon'
      ;;
    rhel|redhat|centos|scientific|oraclelinux|rocky|almalinux)
      family='el'
      ;;
    fedora)
      family='fedora'
      ;;
    sles|suse)
      family='sles'
      ;;
    debian)
      family='debian'
      ;;
    ubuntu)
      family='ubuntu'
      ;;
    *)
      fail "Unhandled platform: '${_platform}'"
      ;;
  esac
  export family # quiets shellcheck SC2034
  assigned 'family'
}

# Based on platform family set:
#  package_type - rpm or deb or...
#  package_file_suffix - the file extension for the release package name
set_package_type() {
  local _family="${1:-${family}}"

  if [[ -z "${_family}" ]]; then
    set_family "${platform}"
    _family="${family}"
  fi

  case $_family in
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
  local _family="${2:-${family}}"
  local _full_version="${3-${full_version}}"

  # Need the full packaging version for deb.
  # As an example, for openvox-agent 8.14.0 on ubuntu 24.04:
  # 8.14.0-1+ubuntu24.04
  if [[ "${_version}" =~ - ]]; then
    # Caller's version already has a '-' seprator, so we
    # should respect that they have probably supplied some
    # full package version string.
    _package_version="${_version}"
  else
    _package_version="${_version}-1+${_family}${_full_version}"
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
  local _family="${3:-${family}}"
  local _full_version="${4:-${full_version}}"

  info "Installing ${_package} ${_version}"

  local _package_and_version
  if [[ -n "${_version}" ]] && [[ "${_version}" != 'latest' ]]; then
    if [[ -z "${_family}" ]]; then
      set_family "${platform}"
      _family="${family}"
    fi
    case $_family in
      debian|ubuntu)
        if [[ -z "${_full_version}" ]]; then
          set_platform
          _full_version="${full_version}"
        fi
        local _deb_package_version
        _deb_package_version=$(get_deb_package_version "${_version}" "${_family}" "${_full_version}")
        _package_and_version="${_package}=${_deb_package_version}"
        ;;
      *)
        _package_and_version="${_package}-${_version}"
        ;;
    esac
  else
    _package_and_version="${_package}"
  fi

  if exists 'dnf'; then
    exec_and_capture dnf install -y "${_package_and_version}"
  elif exists 'yum'; then
    exec_and_capture yum install -y "${_package_and_version}"
  elif exists 'zypper'; then
    exec_and_capture zypper install -y "${_package_and_version}"
  elif exists 'apt'; then
    exec_and_capture apt install -y "${_package_and_version}"
  elif exists 'apt-get'; then
    exec_and_capture apt-get install -y "${_package_and_version}"
  else
    fail "Unable to install ${_package}. Neither dnf, yum, zypper, apt nor apt-get are installed."
  fi
}
