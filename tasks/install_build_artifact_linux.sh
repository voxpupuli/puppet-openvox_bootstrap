#! /usr/bin/env bash

set -e

# PT_* variables are set by Bolt.
# shellcheck disable=SC2154
installdir=$PT__installdir
# shellcheck disable=SC2154
version=${PT_version}
# shellcheck disable=SC2154
package=${PT_package:-'openvox-agent'}
# shellcheck disable=SC2154
artifacts_source=${PT_artifacts_source:-'https://artifacts.voxpupuli.org'}

# shellcheck source=files/common.sh
source "${installdir}/openvox_bootstrap/files/common.sh"

# Lookup the cpu architecture and set it as cpu_arch.
# Translates x86_64 to amd64 and aarch64 to arm64 for debian/ubuntu.
set_architecture() {
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

  assigned 'cpu_arch'
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
set_package_url() {
  local _platform="$1"
  local _package="$2"
  local _version="$3"

  set_package_type "${os_family}"
  set_architecture "${os_family}"

  case "${package_type}" in
    rpm)
      # Account for a fedora naming quirk in the build artifacts.
      if [[ "${os_family}" == "fedora" ]]; then
        _os_family="fc"
      else
        _os_family="${os_family}"
      fi
      package_name="${_package}-${_version}-1.${_os_family}${os_major_version}.${cpu_arch}.${package_type}"
      ;;
    deb)
      package_name="${_package}_${_version}-1%2B${os_family}${os_full_version}_${cpu_arch}.${package_type}"
      ;;
    *)
      fail "Unhandled package type: '${package_type}'"
      ;;
  esac
  package_url="${artifacts_source}/${_package}/${_version}/${package_name}"

  assigned 'package_name'
  assigned 'package_url'
}

# Get platform information
set_platform_globals
# Set url to build artifacts package based on platform
set_package_url "${platform}" "${package}" "${version}"
# Download the build artifacts package to the tempdir.
local_package="${tempdir}/${package_name}"
download "${package_url}" "${local_package}"
# Install the package
install_package_file "${local_package}"
