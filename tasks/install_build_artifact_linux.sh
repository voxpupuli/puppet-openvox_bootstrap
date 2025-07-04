#! /usr/bin/env bash

set -e

# PT_* variables are set by Bolt.
declare PT__installdir
version=${PT_version:-}
package=${PT_package:-openvox-agent}
artifacts_source=${PT_artifacts_source:-https://artifacts.voxpupuli.org}

# shellcheck source=files/common.sh
source "${PT__installdir}/openvox_bootstrap/files/common.sh"

# Get platform information
set_platform_globals
# Set url to build artifacts package based on platform
set_artifacts_package_url "${artifacts_source}" "${package}" "${version}"
# Download the build artifacts package to the tempdir.
local_package="${tempdir}/${package_name}"
download "${package_url}" "${local_package}"
# Install the package
install_package_file "${local_package}"
