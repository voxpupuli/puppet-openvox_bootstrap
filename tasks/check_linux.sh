#! /usr/bin/env bash

set -e

declare PT__installdir
declare PT_version
declare PT_test

bindir='/opt/puppetlabs/puppet/bin'

if ! [ -f "${bindir}/puppet" ]; then
  echo "Error: No puppet binary found at '${bindir}/puppet'. Is the package installed?"
  exit 1
fi

"${bindir}/ruby" "${PT__installdir}/openvox_bootstrap/tasks/check.rb" <<JSON
{
  "version": "${PT_version}",
  "test": "${PT_test}"
}
JSON
