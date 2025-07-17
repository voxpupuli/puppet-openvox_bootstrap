# Simple type for data to be transformed to an INI file format.
type Openvox_bootstrap::Ini_file = Hash[
  String,              # Section name
  Hash[String, String] # Key-value pairs within the section
]
