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
exec_and_capture() {
  local _cmd="$*"

  info "Executing: ${_cmd}"

  local _result
  set +e
  _result=$(${_cmd} 2>&1)
  local _status=$?
  set -e

  echo "${_result}"
  info "Status: ${_status}"
  return $_status
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

# Set platform, full_version and major_version variables by reaching
# out to the puppetlabs-facts bash task as an executable.
set_platform() {
  local facts="${installdir}/facts/tasks/bash.sh"
  if [ -e "${facts}" ]; then
    platform=$(bash "${facts}" platform)
    full_version=$(bash "${facts}" release)
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

# Install a local rpm or deb package file.
install_package_file() {
  local _package_file="$1"
  # If not set, use the file extension of the package file.
  local _package_type="${2:-${_package_file##*.}}"

  info "Installing release package '${_package_file}' of type '${_package_type}'"
  case $_package_type in
    rpm)
      exec_and_capture rpm -Uvh "$_package_file"
      ;;
    deb)
      exec_and_capture dpkg -i "$_package_file"
      ;;
    *)
      fail "Unhandled package type: '${package_type}'"
      ;;
  esac
}

# Install a package using the system package manager.
install_package() {
  local _package="$1"
  local _version="$2"
  local _family="${3:-${family}}"

  info "Installing ${_package} ${_version}"

  local _package_and_version
  if [[ -n "${_version}" ]] && [[ "${_version}" != 'latest' ]]; then
    if [[ -z "${_family}" ]]; then
      set_family "${platform}"
      _family="${family}"
    fi
    case $_family in
      debian|ubuntu)
        _package_and_version="${_package}=${_version}"
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
