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

  case "${package_type}" in
    rpm)
      package_name="${collection}-release-${family}-${major_version}.${package_file_suffix}"
      ;;
    deb)
      package_name="${collection}-release-${family}${full_version}.${package_file_suffix}"
      ;;
    *)
      fail "Unhandled package type: '${package_type}'"
      ;;
  esac
  package_url="${repository}/${package_name}"

  assigned 'package_name'
  assigned 'package_url'
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

# Installs the release package, and runs apt update if we are on a
# Debian based platform.
install_release_package() {
  local _release_package="$1"
  local _package_type="$2"

  install_package_file "${_release_package}"
  if [[ "${_package_type}" == "deb" ]]; then
    exec_and_capture apt update
  fi
}

# Get platform information
set_platform
# Set collection release package url based on platform
set_collection_url "${platform}"
# Download the release package to tempdir
local_release_package="${tempdir}/${package_name}"
download "${package_url}" "${local_release_package}"
# Install the release package.
# The release package has the repository metadata needed to install
# packages from the collection using the platform package manager.
install_release_package "${local_release_package}" "${package_type}"
# Use the platform package manager to install openvox-agent
install_package 'openvox-agent'
