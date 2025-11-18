# Changelog

All notable changes to this project will be documented in this file.
Each new release typically also includes the latest modulesync defaults.
These should not affect the functionality of the module.

## [Unreleased](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/HEAD)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/v1.1.0...HEAD)

**Implemented enhancements:**

- Add Windows support for install and check tasks [\#44](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/44) ([austb](https://github.com/austb))

## [v1.1.0](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/v1.1.0) (2025-10-26)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/v1.0.0...v1.1.0)

**Implemented enhancements:**

- Configure openbox\_bootstrap as a puppet\_library bolt\_plugin [\#33](https://github.com/voxpupuli/puppet-openvox_bootstrap/issues/33)
- Exit install early if nothing to do [\#42](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/42) ([austb](https://github.com/austb))

**Closed issues:**

- Add Feature to manage entries in csr\_attributes.yml [\#26](https://github.com/voxpupuli/puppet-openvox_bootstrap/issues/26)

**Merged pull requests:**

- \(gh-35\) Add a stop\_service parameter to install task [\#36](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/36) ([jpartlow](https://github.com/jpartlow))
- \(gh-33\) Configure openbox\_boostrap as a puppet\_library bolt plugin [\#34](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/34) ([jpartlow](https://github.com/jpartlow))

## [v1.0.0](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/v1.0.0) (2025-08-04)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/v0.4.0...v1.0.0)

**Breaking changes:**

- Drop puppet, update openvox minimum version to 8.19 [\#31](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/31) ([TheMeier](https://github.com/TheMeier))

**Merged pull requests:**

- \(maint\) Drop debian-10 from testing matrix [\#28](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/28) ([jpartlow](https://github.com/jpartlow))
- Configure openvox [\#27](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/27) ([jpartlow](https://github.com/jpartlow))

## [v0.4.0](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/v0.4.0) (2025-07-04)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/v0.3.3...v0.4.0)

**Merged pull requests:**

- Handle noarch artifacts [\#24](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/24) ([jpartlow](https://github.com/jpartlow))

## [v0.3.3](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/v0.3.3) (2025-06-03)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/v0.3.2...v0.3.3)

**Fixed bugs:**

- Calling curl --fail-with-body fails on almalinux 8 vm, presumably with a curl pre-dating that parameter [\#20](https://github.com/voxpupuli/puppet-openvox_bootstrap/issues/20)

**Merged pull requests:**

- \(gh-20\) Download with curl --fail instead of --fail-with-body [\#21](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/21) ([jpartlow](https://github.com/jpartlow))

## [v0.3.2](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/v0.3.2) (2025-05-29)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/v0.3.1...v0.3.2)

**Merged pull requests:**

- CI: Cleanup redundant jobs [\#18](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/18) ([bastelfreak](https://github.com/bastelfreak))
- modulesync 9.7.0 [\#17](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/17) ([bastelfreak](https://github.com/bastelfreak))

## [v0.3.1](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/v0.3.1) (2025-05-29)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/0.3.0...v0.3.1)

**Fixed bugs:**

- fix curl error handling [\#13](https://github.com/voxpupuli/puppet-openvox_bootstrap/issues/13)

**Merged pull requests:**

- \(gh-13\) Fail for curl 404 and add specs for common.sh lib [\#14](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/14) ([jpartlow](https://github.com/jpartlow))
- modulesync 9.5.0 [\#12](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/12) ([bastelfreak](https://github.com/bastelfreak))

## [0.3.0](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/0.3.0) (2025-05-14)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/v0...0.3.0)

## [v0](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/v0) (2025-05-14)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/0.2.1...v0)

**Merged pull requests:**

- \(doc\) Add and test for current REFERENCE.md using puppet-strings [\#11](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/11) ([jpartlow](https://github.com/jpartlow))
- \(maint\) Update source urls to voxpupuli.org [\#10](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/10) ([jpartlow](https://github.com/jpartlow))

## [0.2.1](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/0.2.1) (2025-05-08)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/0.2.0...0.2.1)

**Merged pull requests:**

- Fix retry function [\#9](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/9) ([jpartlow](https://github.com/jpartlow))

## [0.2.0](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/0.2.0) (2025-05-07)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/0.1.0...0.2.0)

**Merged pull requests:**

- \(tasks\) Provide retry logic for  install\_package\_file [\#8](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/8) ([jpartlow](https://github.com/jpartlow))

## [0.1.0](https://github.com/voxpupuli/puppet-openvox_bootstrap/tree/0.1.0) (2025-05-01)

[Full Changelog](https://github.com/voxpupuli/puppet-openvox_bootstrap/compare/dc87b8352087799507e9cf6d91ba5bebd0143bc2...0.1.0)

**Merged pull requests:**

- Handle debian pre release builds [\#7](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/7) ([jpartlow](https://github.com/jpartlow))
- \(tasks,gha\) Fix a case issue that was blocking almalinux installs [\#6](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/6) ([jpartlow](https://github.com/jpartlow))
- \(tasks,gha\) Implement version parameter for install task [\#5](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/5) ([jpartlow](https://github.com/jpartlow))
- Install from build artifacts [\#4](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/4) ([jpartlow](https://github.com/jpartlow))
- \(tasks\) Set defaults for collection and repos in install\_linux.sh [\#3](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/3) ([jpartlow](https://github.com/jpartlow))
- \(gha\) Test install in gha on other os's using containers [\#2](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/2) ([jpartlow](https://github.com/jpartlow))
- GHA  Fix up basic pr test workflow [\#1](https://github.com/voxpupuli/puppet-openvox_bootstrap/pull/1) ([jpartlow](https://github.com/jpartlow))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
