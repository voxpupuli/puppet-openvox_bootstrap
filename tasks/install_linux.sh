#! /usr/bin/env bash

set -e

# PT_* variables are set by Bolt.
# shellcheck disable=SC2154
installdir=$PT__installdir
# shellcheck disable=SC2154
version=${PT_version:-'latest'}
# shellcheck disable=SC2154
collection=${PT_collection:-'openvox8'}
# shellcheck disable=SC2154
yum_source=${PT_yum_source:-'https://yum.voxpupuli.org'}
# shellcheck disable=SC2154
apt_source=${PT_apt_source:-'https://apt.voxpupuli.org'}

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

# Installs the openvox-agent package using the system package manager.
# The version is optional, and if not provided, the latest version
# available in the repository will be installed.
install_openvox_agent() {
  local _version="$1"
  local _family="$2"
  local _full_version="$3"

  local _package_version
  if [[ -n "${_version}" ]] && [[ "${_version}" != 'latest' ]]; then
    case $_family in
      debian|ubuntu)
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
        ;;
      *)
        # rpm packages should be fine so long as the shorter form
        # matches uniquely.
        _package_version="${_version}"
        ;;
    esac
  fi

  install_package openvox-agent "${_package_version}" "${_family}"
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
install_openvox_agent "${version}" "${family}" "${full_version}"
