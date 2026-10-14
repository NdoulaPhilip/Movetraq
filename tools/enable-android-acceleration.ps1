$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an Administrator PowerShell window to enable Windows Hypervisor Platform.'
}
Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart
& bcdedit.exe /set hypervisorlaunchtype auto
if ($LASTEXITCODE -ne 0) { throw 'Could not enable hypervisor startup.' }
Write-Host 'Windows Hypervisor Platform is enabled. Save your work and restart Windows manually before starting the emulator.'
