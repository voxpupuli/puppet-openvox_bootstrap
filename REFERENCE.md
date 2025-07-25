# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Data types

* [`Openvox_bootstrap::Cer_short_names`](#Openvox_bootstrap--Cer_short_names): Certificate extension request short names. These are the allowed short names documented for Puppet(TM) extension requests per [csr_attributes
* [`Openvox_bootstrap::Csr_attributes`](#Openvox_bootstrap--Csr_attributes): [csr_attributes.yaml](https://help.puppet.com/core/current/Content/PuppetCore/config_file_csr_attributes.htm)
* [`Openvox_bootstrap::Ini_file`](#Openvox_bootstrap--Ini_file): Simple type for data to be transformed to an INI file format.
* [`Openvox_bootstrap::Oid`](#Openvox_bootstrap--Oid): Object Identifier per https://en.wikipedia.org/wiki/Object_identifier

### Tasks

* [`check`](#check): Check whether a Puppet(tm) implementation is installed. Optionally checks the version.
* [`configure`](#configure): Provides initial configuration for a freshly installed openvox-agent.
* [`install`](#install): Installs an openvox package. By default, this will be the latest openvox-agent from the latest collection.
* [`install_build_artifact`](#install_build_artifact): Downloads and installs a package directly from the openvox build artifact server.

## Data types

### <a name="Openvox_bootstrap--Cer_short_names"></a>`Openvox_bootstrap::Cer_short_names`

Certificate extension request short names.
These are the allowed short names documented for Puppet(TM)
extension requests per [csr_attributes.yaml](https://help.puppet.com/core/current/Content/PuppetCore/config_file_csr_attributes.htm)

Alias of `Enum['pp_uuid', 'pp_instance_id', 'pp_image_name', 'pp_preshared_key', 'pp_cost_center', 'pp_product', 'pp_project', 'pp_application', 'pp_service', 'pp_employee', 'pp_created_by', 'pp_environment', 'pp_role', 'pp_software_version', 'pp_department', 'pp_cluster', 'pp_provisioner', 'pp_region', 'pp_datacenter', 'pp_zone', 'pp_network', 'pp_securitypolicy', 'pp_cloudplatform', 'pp_apptier', 'pp_hostname', 'pp_authorization', 'pp_auth_role']`

### <a name="Openvox_bootstrap--Csr_attributes"></a>`Openvox_bootstrap::Csr_attributes`

[csr_attributes.yaml](https://help.puppet.com/core/current/Content/PuppetCore/config_file_csr_attributes.htm)

Alias of

```puppet
Struct[{
    Optional['custom_attributes']  => Hash[
      Openvox_bootstrap::Oid,
      String
    ],
    Optional['extension_requests'] => Hash[
      Variant[Openvox_bootstrap::Oid,Openvox_bootstrap::Cer_short_names],
      String
    ],
  }]
```

### <a name="Openvox_bootstrap--Ini_file"></a>`Openvox_bootstrap::Ini_file`

Simple type for data to be transformed to an INI file format.

Alias of `Hash[String, Hash[String, String]]`

### <a name="Openvox_bootstrap--Oid"></a>`Openvox_bootstrap::Oid`

Object Identifier per https://en.wikipedia.org/wiki/Object_identifier

Alias of `Pattern[/\d+(\.\d+)*/]`

## Tasks

### <a name="check"></a>`check`

Check whether a Puppet(tm) implementation is installed. Optionally checks the version.

**Supports noop?** false

#### Parameters

##### `version`

Data type: `Optional[String]`

The version of the implementation to check. To check if version meets a minimum, set test to 'ge' and version to x, x.y or x.y.z

##### `test`

Data type: `Enum['eq', 'lt', 'le', 'gt', 'ge']`

Version comparison operator.

### <a name="configure"></a>`configure`

Provides initial configuration for a freshly installed openvox-agent.

**Supports noop?** false

#### Parameters

##### `puppet_conf`

Data type: `Optional[Openvox_bootstrap::Ini_file]`

Hash of puppet configuration settings to add to the puppet.conf ini file. These will be merged into the existing puppet.conf, if any.

##### `csr_attributes`

Data type: `Optional[Openvox_bootstrap::Csr_attributes]`

Hash of CSR attributes (custom_attributes and extension_requests) to write to the csr_attributes.yaml file. NOTE: This will completely overwrite any pre-existing csr_attributes.yaml.

##### `puppet_service_running`

Data type: `Boolean`

Whether the Puppet service should be running after this task completes. Defaults to true.

##### `puppet_service_enabled`

Data type: `Boolean`

Whether the Puppet service should be enabled to start on boot after this task completes. Defaults to true.

### <a name="install"></a>`install`

Installs an openvox package. By default, this will be the latest openvox-agent from the latest collection.

**Supports noop?** false

#### Parameters

##### `package`

Data type: `String[1]`

The name of the package to install.

##### `version`

Data type: `Optional[String]`

The version of the openvox-agent package to install. Defaults to latest.

##### `collection`

Data type: `Optional[String]`

The openvox collection to install from.

##### `apt_source`

Data type: `Optional[String]`

The apt source repository to retrieve deb packages from.

##### `yum_source`

Data type: `Optional[String]`

The yum source repository to retrieve rpm packages from.

### <a name="install_build_artifact"></a>`install_build_artifact`

Downloads and installs a package directly from the openvox build artifact server.

**Supports noop?** false

#### Parameters

##### `package`

Data type: `String[1]`

The name of the package to install.

##### `version`

Data type: `String[1]`

The version of the package to install.

##### `artifacts_source`

Data type: `String[1]`

URL to the build artifacts server.

