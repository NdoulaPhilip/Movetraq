$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$adb = 'C:\Users\User\flutter\DevelopmentTools\Android\platform-tools\adb.exe'
$player = 'C:\Program Files\BlueStacks_nxt\HD-Player.exe'
if (-not (Get-Process HD-Player -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $player -ArgumentList '--instance Pie64'
}
$connected = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    & $adb connect 127.0.0.1:5555 | Out-Null
    if ((& $adb -s 127.0.0.1:5555 get-state 2>$null) -eq 'device') {
        $connected = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $connected) { throw 'BlueStacks ADB is unavailable. Enable Android Debug Bridge in BlueStacks settings.' }
$configPath = Join-Path $projectRoot 'mobile/config/bluestacks.json'
if (-not (Test-Path $configPath)) {
    $config = Get-Content (Join-Path $projectRoot 'mobile/config/development.json') -Raw | ConvertFrom-Json
    $config.API_URL = 'http://127.0.0.1:3000'
    $config | ConvertTo-Json | Set-Content $configPath -Encoding utf8
}
& $adb -s 127.0.0.1:5555 reverse tcp:3000 tcp:3000
Push-Location (Join-Path $projectRoot 'mobile')
try {
    & flutter.bat run -d 127.0.0.1:5555 --dart-define-from-file=config/bluestacks.json --no-resident
    if ($LASTEXITCODE -ne 0) { throw 'Flutter could not launch MoveTraq.' }
} finally { Pop-Location }
