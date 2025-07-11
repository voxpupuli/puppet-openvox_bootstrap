# Certificate extension request short names.
# These are the allowed short names documented for Puppet(TM)
# extension requests per [csr_attributes.yaml](https://help.puppet.com/core/current/Content/PuppetCore/config_file_csr_attributes.htm)
type Openvox_bootstrap::Cer_short_names = Enum[
  # 1.3.6.1.4.1.34380.1.1 range
  'pp_uuid',
  'pp_instance_id',
  'pp_image_name',
  'pp_preshared_key',
  'pp_cost_center',
  'pp_product',
  'pp_project',
  'pp_application',
  'pp_service',
  'pp_employee',
  'pp_created_by',
  'pp_environment',
  'pp_role',
  'pp_software_version',
  'pp_department',
  'pp_cluster',
  'pp_provisioner',
  'pp_region',
  'pp_datacenter',
  'pp_zone',
  'pp_network',
  'pp_securitypolicy',
  'pp_cloudplatform',
  'pp_apptier',
  'pp_hostname',
  # 1.3.6.1.4.1.34380.1.3 range
  'pp_authorization',
  'pp_auth_role',
]
