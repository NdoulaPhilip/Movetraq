param([switch]$Headless)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sdkPath = $env:ANDROID_SDK_ROOT
if (!$sdkPath) { $sdkPath = $env:ANDROID_HOME }
if (!$sdkPath) { throw 'Set ANDROID_SDK_ROOT to the installed Android SDK.' }
$emulatorPath = Join-Path $sdkPath 'emulator/emulator.exe'
if ($env:ANDROID_USER_HOME) { $env:ANDROID_AVD_HOME = Join-Path $env:ANDROID_USER_HOME 'avd' }
& $emulatorPath -accel-check
if ($LASTEXITCODE -ne 0) { throw 'Android acceleration is unavailable. See tools/enable-android-acceleration.ps1 or connect an Android phone.' }
$arguments = '-avd MoveTraq_Android -gpu swiftshader -no-audio -no-snapshot'
if ($Headless) { $arguments += ' -no-window' }
# The default invocation is an explicit user command to open the interactive emulator.
if ($Headless) {
    Start-Process -FilePath $emulatorPath -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $projectRoot 'android-emulator.stdout.log') -RedirectStandardError (Join-Path $projectRoot 'android-emulator.stderr.log') | Out-Null
} else {
    Start-Process -FilePath $emulatorPath -ArgumentList $arguments | Out-Null
}
Write-Host 'Emulator started. Wait for Android to finish booting, then run flutter.bat devices from mobile.'
Write-Host 'Run: flutter.bat run -d emulator-5554 --dart-define-from-file=config/development.json'
