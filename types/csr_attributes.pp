# [csr_attributes.yaml](https://help.puppet.com/core/current/Content/PuppetCore/config_file_csr_attributes.htm)
type Openvox_bootstrap::Csr_attributes = Struct[
  {
    Optional['custom_attributes']  => Hash[
      Openvox_bootstrap::Oid,
      String
    ],
    Optional['extension_requests'] => Hash[
      Variant[Openvox_bootstrap::Oid,Openvox_bootstrap::Cer_short_names],
      String
    ],
  }
]
