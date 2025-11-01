[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$package = "openvox-agent",

  [Parameter(Mandatory = $false)]
  [string]$version = "latest",

  [Parameter(Mandatory = $false)]
  [string]$collection = "openvox8",

  [Parameter(Mandatory = $false)]
  [string]$apt_source = "https://apt.voxpupuli.org",

  [Parameter(Mandatory = $false)]
  [string]$yum_source = "https://yum.voxpupuli.org",

  [Parameter(Mandatory = $false)]
  [bool]$stop_service = $false
)

$agent_package = "openvox-agent"

$ErrorActionPreference = "Stop"

function Write-Result($status, $message, $extra = @{}) {
  $output = @{
    status  = $status
    message = $message
  } + $extra
  $output | ConvertTo-Json -Compress
  if ($status -eq "failure") { exit 1 } else { exit 0 }
}

# Exit if anything other than the agent is requested
if ($package -ne $agent_package) {
  Write-Result "failure" "Unsupported package name '$package'. This task only supports '$agent_package'."
}

try {
  # Detect if already installed
  $installed = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Where-Object { $_.DisplayName -like "$agent_package*" } |
    Select-Object -First 1

  if ($installed) {
    $installedVersion = $installed.DisplayVersion
    if ($installedVersion -eq $version) {
      Write-Result "skipped" "$agent_package $version is already installed." @{ version = $installedVersion }
    }
  }

  # Service handling
  $serviceName = "Puppet Agent"
  $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

  if ($service) {
    if ($service.Status -eq "Running") {
      if ($stop_service) {
        Write-Verbose "Stopping $serviceName service as requested."
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
      } else {
        Write-Result "failure" "The $serviceName service is running. Use stop_service=true to allow upgrade."
      }
    }
  }

  # Resolve "latest" version if requested
  if ($version -eq "latest") {
    $version = '8.23.1'
  }

  # Build download URL
  $baseUrl = "https://artifacts.voxpupuli.org/downloads/windows/$collection"
  $installer = "$($agent_package)-$($version)-x64.msi"
  $url = "$baseUrl/$installer"
  $installerPath = Join-Path $env:TEMP $installer
  $installLog = Join-Path $env:TEMP "$($agent_package)-install.log"

  # Download installer
  Write-Verbose "Downloading from $url"
  Invoke-WebRequest -Uri $url -OutFile $installerPath

  # Install package silently
  Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn /norestart /log `"$installLog`"" -Wait

  # Cleanup downloaded artifacts
  Remove-Item -Path $installerPath -ErrorAction SilentlyContinue
  Remove-Item -Path $installLog -ErrorAction SilentlyContinue

  # Restart service if previously running
  if ($service -and $stop_service) {
    Write-Verbose "Restarting $serviceName service."
    Start-Service -Name $serviceName -ErrorAction SilentlyContinue
  }

  # Return success result
  Write-Result "success" "$agent_package $version installed successfully." @{
    package = $agent_package
    version = $newInstall.DisplayVersion
    source  = $url
  }

} catch {
  Write-Result "failure" $_.Exception.Message
}
