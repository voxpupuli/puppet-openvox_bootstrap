# openvox_bootstrap

[Bolt] module for bootstrapping installation of the [openvox]
(Puppet<sup>:tm:</sup>) packages.

Provides some of the functionality of the [puppet_agent::install
tasks] for [openvox] packages from https://apt.voxpupuli.org,
https://yum.voxpupuli.org.

The puppet_agent module makes use of the Perforce repositories and
collections instead.

## Usage

Assumes you have Bolt installed.

### openvox_boostrap::install

Installs the platform appropriate openvox8 collection release package
and the openvox-agent package by default (Puppet<sup>:tm:</sup> 8).

```sh
bolt task run openvox_bootstrap::install \
  --targets <target> \
  --run-as root
```
#### parameters

By default the task will install the openvox-agent package, but this
can be overridden by setting the `package` parameter to install
openvox-server, openvoxdb or another package from the openvox
collection.

See the [install task](./REFERENCE.md#install) for details.

#### Usage with Bolt apply_prep() function

Bolt's [apply_prep] function ensures that the latest version of
Puppet<sup>:tm:</sup> is installed on a node by calling the
`puppet_agent::install` task if the agent is not detected on the node.

The `openvox_bootstrap::install` task can be used in its place to
instead ensure that openvox-agent is installed.

The apply_prep() function relies on Bolt's [puppet_library] plugin
configuration.

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

Minimally, you must supply the `version` parameter, but generally you
would also supply `package` unless you are installing the
openvox-agent package.

See [task ref](./REFERENCE.md#install_build_artifact) for details.

```sh
bolt task run openvox_bootstrap::install_build_artifact \
  --targets <target> --version=8.17.0 \
  --run-as root
```

## Reference

See [REFERENCE.md](./REFERENCE.md) for the generated reference doc.

## TODO

* Windows support
* Sles support (handle repository gpg key)
* MacOS support

## History

This module started as jpartlow/openvox_bootstrap and has been renamed
puppet-openvox_bootstrap and moved over to the voxpupuli organization.

It was only out and about as jpartlow/openvox_bootstrap for a few
months, but if you have a reference to jpartlow/openvox_bootstrap or
jpartlow/puppet-openvox_bootstrap, please update to
voxpupuli/puppet-openvox_bootstrap, as my fork will be out of sync
and/or experimental going forward.

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

[bolt]: https://puppet.com/docs/bolt/latest/bolt.html
[openvox]: https://voxpupuli.org/openvox/
[puppet_agent::install tasks]: https://github.com/puppetlabs/puppetlabs-puppet_agent/tree/main?tab=readme-ov-file#puppet_agentinstall
[apply_prep]: https://www.puppet.com/docs/bolt/latest/plan_functions#apply-prep
[puppet_library]: https://www.puppet.com/docs/bolt/latest/using_plugins#puppet-library-plugins
