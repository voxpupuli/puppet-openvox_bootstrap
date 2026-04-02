[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$version = $null,

  [Parameter(Mandatory = $false)]
  [ValidateSet("eq", "gt", "lt", "ge", "le")]
  [string]$test = "eq"
)

$rootPath = 'HKLM:\SOFTWARE\Puppet Labs\Puppet'

$reg = Get-ItemProperty -Path $rootPath -ErrorAction SilentlyContinue
if ($null -ne $reg) {
  if ($null -ne $reg.RememberedInstallDir64) {
    $loc = Join-Path $reg.RememberedInstallDir64 'VERSION'
  } elseif ($null -ne $reg.RememberedInstallDir) {
    $loc = Join-Path $reg.RememberedInstallDir 'VERSION'
  }
}

if (($null -ne $loc) -and (Test-Path -Path $loc)) {
  $installedVersion = [string](Get-Content -Path $loc -ErrorAction Stop)
  $result = @{
    puppet_version = $installedVersion
    source = $loc.replace('\', '/')
  }
} else {
  Write-Error "Error: The openvox-agent is not installed."
  exit 1
}

# XXX Powershell's Version object only supports 4 numeric components. Unlike
# check.rb's Gem::Version usage, it does not support pre-release or build
# metadata and will throw an error if the version string contains more than 4
# components.
if ($version) {
  $installed = [Version]$installedVersion
  # Version requires at least a maj.min string, or it throws an error...
  $expected  = [Version]($version -replace '^(\d+)$', '$1.0')
  $result.test = $test
  $result.test_version = $version
  $result.valid = switch ($test) {
    "eq" { $installed -eq $expected }
    "gt" { $installed -gt $expected }
    "lt" { $installed -lt $expected }
    "ge" { $installed -ge $expected }
    "le" { $installed -le $expected }
  }
} else {
  $result.valid = $true
}

Write-Output ($result | ConvertTo-Json)
if ($result.valid) { exit 0 } else { exit 1 }
