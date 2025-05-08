# openvox_bootstrap

[Bolt](https://www.puppet.com/docs/bolt/latest/bolt.html) module for
bootstrapping installation of the openvox-agent package.

Provides some of the functionality of the [puppet_agent::install
tasks](https://github.com/puppetlabs/puppetlabs-puppet_agent/tree/main?tab=readme-ov-file#puppet_agentinstall)
for [openvox](https://voxpupuli.org/openvox/) packages from
https://apt.voxpupuli.org, https://yum.voxpupuli.org.

The puppet_agent module makes use of the Perforce repositories and
collections instead.

## Usage

Assumes you have Bolt installed.

### openvox_boostrap::install

Installs the openvox8 collection by default (Puppet<sup>:tm:</sup> 8).

```sh
bolt task run openvox_bootstrap::install \
  --targets <target> \
  --run-as root
```

#### Usage with Bolt apply_prep() function

Bolt's
[apply_prep](https://www.puppet.com/docs/bolt/latest/plan_functions#apply-prep)
function ensures that the latest version of Puppet<sup>:tm:</sup> is installed on
a node by calling the puppet_agent::install task if the agent is not
detected on the node.

The openvox_bootstrap::install task can be used in its place to
instead ensure that openvox-agent is installed.

The apply_prep() function relies on Bolt's
[puppet_library](https://www.puppet.com/docs/bolt/latest/using_plugins#puppet-library-plugins)
plugin configuration.

To use openvox_bootstrap instead, configure your bolt_project.yaml
with:

```yaml
plugin-hooks:
  puppet_library:
    plugin: task
    task: openvox_bootstrap::install
```

### openvox_bootstrap::install_build_artifact

The openvox_bootstrap::install_build_artifact task is a development
task that can be used to install a build artifact package directly
from the https://artifact.voxpupuli.org repository for testing
prior to release.

```sh
bolt task run openvox_bootstrap::install \
  --targets <target> \
  --run-as root
```

## TODO

* Windows support
* Sles support (handle repository gpg key)
* MacOS support

## License

Copyright (C) 2025 Joshua Partlow

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
