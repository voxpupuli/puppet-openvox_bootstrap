## 0.2.1 (2025-05-07)

* (bug) fixed retry logic bypassed by failed command
* (bug) fixed install tasks on redhat variants not being idempotent
  for package file installation
* (gha) added idempotency tests for install tasks

## 0.2.0 (2025-05-07)

* retry logic for lock failures running rpm/dpkg during manual
  install of openvox-release package

## 0.1.0 (2025-05-01)

* openvox_bootstrap::install task to install the openvox-agent
* openvox_bootstrap::install_build_artifacts task to install the
  openvox-agent from build artifacts
* debian support
* ubuntu support
* rhel variant support (rocky/alma)
* fedora support
* support for installing build artifacts on debian 13/14 pre-release
  images
* can install specific package versions
* gha pipeline testing
