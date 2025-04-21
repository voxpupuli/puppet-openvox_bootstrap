#! /usr/bin/env bash

set -e

# PT_* variables are set by Bolt.
# shellcheck disable=SC2154
installdir=$PT__installdir
# shellcheck disable=SC2154
collection=${PT_collection:-'openvox8'}
# shellcheck disable=SC2154
yum_source=${PT_yum_source:-'https://yum.overlookinfratech.com'}
# shellcheck disable=SC2154
apt_source=${PT_apt_source:-'https://apt.overlookinfratech.com'}

# shellcheck source=files/common.sh
source "${installdir}/openvox_bootstrap/files/common.sh"

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

# Based on the platform set:
#   package_name - the name of the release package
#   package_url - the url to download the release package
set_collection_url() {
  local _platform="$1"

  set_family "${_platform}"
  set_repository "${family}"
  set_package_type "${family}"

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

# TODO add support for the version parameter.
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
  elif exists 'apt-get'; then
    exec_and_capture apt-get install -y "$_package"
  else
    fail "Unable to install ${_package}. Neither dnf, yum, zypper, apt nor apt-get are installed."
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
