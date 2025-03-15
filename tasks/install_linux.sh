#! /usr/bin/env bash

set -e

# PT_* variables are set by Bolt.
# shellcheck disable=SC2154
installdir=$PT__installdir
# shellcheck disable=SC2154
collection=$PT_collection
# shellcheck disable=SC2154
yum_source=$PT_yum_source
# shellcheck disable=SC2154
apt_source=$PT_apt_source

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

# Set platform and full_version variables by reaching out to the
# puppetlabs-facts bash task as an executable.
set_platform() {
  # PT__installdir is set by Bolt.
  local facts="${installdir}/facts/tasks/bash.sh"
  if [ -e "${facts}" ]; then
    platform=$(bash "${facts}" platform)
    assigned 'platform'
    full_version=$(bash "${facts}" release)
    assigned 'full_version'
  else
    fail "Unable to find the puppetlabs-facts bash task to determine platform at '${facts}'."
  fi
}

# Based on platform family set:
#   repository - the package repository to download from
set_repository() {
  local _family="$1"

  case $_family in
    amazon|fedora|el|sles)
      repository=$yum_source
      ;;
    debian|ubuntu)
      repository=$apt_source
      ;;
  esac
  assigned 'repository'
}

# Based on platform family set:
#  package_type - rpm or deb or...
#  package_file_suffix - the file extension for the release package name
set_package_type() {
  local _family="$1"

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
  assigned 'package_type'
  assigned 'package_file_suffix'
}

# Based on the platform set:
#   package_name - the name of the release package
#   package_url - the url to download the release package
set_collection_url() {
  local _platform="$1"

  case $_platform in
    Amazon)
      family='amazon'
      ;;
    RHEL|RedHat|CentOS|Scientific|OracleLinux|Rocky|AlmaLinux)
      family='el'
      ;;
    Fedora)
      family='fedora'
      ;;
    SLES|Suse)
      family='sles'
      ;;
    Debian)
      family='debian'
      ;;
    Ubuntu)
      family='ubuntu'
      ;;
    *)
      fail "Unhandled platform: '${platform}'"
      ;;
  esac
  assigned 'family'

  set_repository $family
  set_package_type $family

  if [ "${package_type}" == 'rpm' ]; then
    major_version=${full_version%%.*}
    assigned 'major_version'
    package_name="${collection}-release-${family}-${major_version}.${package_file_suffix}"
  else
    package_name="${collection}-release-${family}${full_version}.${package_file_suffix}"
  fi
  package_url="${repository}/${package_name}"

  assigned 'package_name'
  assigned 'package_url'
}

exec_and_capture() {
  local _cmd="$*"

  info "Executing: ${_cmd}"
  local _result

  set +e
  result=$(${_cmd} 2>&1)
  local _status=$?
  set -e

  echo "${result}"
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

# Download the release package to the tempdir.
# Sets:
#   local_release_package - the path to the downloaded release package.
download_release_package() {
  local _package_url="$1"
  local _package_name="$2"

  local_release_package="${tempdir}/${_package_name}"
  assigned 'local_release_package'

  download "${_package_url}" "${local_release_package}"
}

# Install the downloaded release package.
# The release package has the repository metadata needed to install packages
# from the collection using the platform package manager.
install_release_package() {
  local _package_type="$1"
  local _package_file="$2"

  info "Installing release package: ${_package_file}"
  case $_package_type in
    rpm)
      exec_and_capture rpm -Uvh "$_package_file"
      ;;
    deb)
      exec_and_capture dpkg -i "$_package_file"
      exec_and_capture apt update
      ;;
    *)
      fail "Unhandled package type: '${package_type}'"
      ;;
  esac
}

install_package() {
  local _package="$1"

  info "Installing ${_package}"
  if exists 'dnf'; then
    exec_and_capture dnf install -y "$_package"
  elif exists 'yum'; then
    exec_and_capture yum install -y "$_package"
  elif exists 'zypper'; then
    exec_and_capture zypper install -y "$_package"
  elif exists 'apt'; then
    exec_and_capture apt install -y "$_package"
  else
    fail "Unable to install ${_package}. Neither dnf, yum, zypper, nor apt are installed."
  fi
}

# Get platform information
set_platform
# Set collection release package url based on platform
set_collection_url "${platform}"
# Download the release package to tempdir
download_release_package "${package_url}" "${package_name}"
# Install the release package
install_release_package "${package_type}" "${local_release_package}"
# Use the platform package manager to install openvox-agent
install_package 'openvox-agent'
