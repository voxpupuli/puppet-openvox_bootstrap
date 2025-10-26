#! /usr/bin/env bash

set -e

# PT_* variables are set by Bolt.
declare PT__installdir
package=${PT_package:-openvox-agent}
version=${PT_version:-latest}
collection=${PT_collection:-openvox8}
yum_source=${PT_yum_source:-https://yum.voxpupuli.org}
apt_source=${PT_apt_source:-https://apt.voxpupuli.org}
stop_service=${PT_stop_service:-'false'}

# shellcheck source=files/common.sh
source "${PT__installdir}/openvox_bootstrap/files/common.sh"

# This function will cause the script to exit if one of the conditions is met
#
# If the requested $version is
#   1. latest and there is already an agent installed
#   2. not latest, but $version matches the agent's version number
skip_if_installed() {
  # This logic only applies to the agent package because it enables
  # OpenBolt's apply_prep logic to work properly
  if [ "$package" == 'openvox-agent' ]; then
    # Find agent version, if any
    if [ -f /opt/puppetlabs/puppet/VERSION ]; then
      installed_version=$(cat /opt/puppetlabs/puppet/VERSION)
    elif command -v puppet >/dev/null 2>&1; then
      installed_version=$(puppet --version)
    else
      installed_version=none
    fi

    if [ "$installed_version" != 'none' ]; then
      if [ "$version" = 'latest' ]; then
        info 'Specific agent version not requested and the agent was detected. Skipping install.'
        exit 0
      elif [ "$version" = "$installed_version" ]; then
        # installed agent version matched specific version requested
        info "Requested agent version $version. Found agent version $installed_version. Skipping install."
        exit 0
      fi
    fi
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

# Based on the platform set:
#   package_name - the name of the release package
#   package_url - the url to download the release package
set_collection_url() {
  local _platform="$1"

  set_repository "${os_family}"
  set_package_type "${os_family}"

  case "${package_type}" in
    rpm)
      package_name="${collection}-release-${os_family}-${os_major_version}.${package_file_suffix}"
      ;;
    deb)
      package_name="${collection}-release-${os_family}${os_full_version}.${package_file_suffix}"
      ;;
    *)
      fail "Unhandled package type: '${package_type}'"
      ;;
  esac
  package_url="${repository}/${package_name}"

  assigned 'package_name'
  assigned 'package_url'
}

# Installs the release package, and refreshes the package manager's
# cache.
install_release_package() {
  local _release_package="$1"

  install_package_file "${_release_package}"
  refresh_package_cache
}

# quit early if nothing to do
skip_if_installed
# Get platform information
set_platform_globals
# Set collection release package url based on platform
set_collection_url "${platform}"
# Download the release package to tempdir
local_release_package="${tempdir}/${package_name}"
download "${package_url}" "${local_release_package}"
# Install the release package.
# The release package has the repository metadata needed to install
# packages from the collection using the platform package manager.
install_release_package "${local_release_package}"
# Use the platform package manager to install $package
install_package "${package}" "${version}" "${os_family}" "${os_full_version}"
# If a service stop is requested, stop the service now
if [[ "${stop_service}" = 'true' ]]; then
  stop_and_disable_service "${package}"
fi
