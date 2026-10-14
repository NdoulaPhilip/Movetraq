$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $projectRoot 'backend'
$adminPath = Join-Path $projectRoot 'admin'
foreach ($path in @($backendPath, $adminPath)) {
    if (!(Test-Path -LiteralPath (Join-Path $path 'node_modules'))) {
        throw "Install dependencies first: cd $path; npm.cmd ci"
    }
}
if (!(Test-Path -LiteralPath (Join-Path $backendPath '.env'))) {
    throw 'Configure backend/.env from .env.example before starting local services.'
}
Push-Location $backendPath
try {
    & npm.cmd run build
    if ($LASTEXITCODE -ne 0) { throw 'Backend build failed; no services were started.' }
    $configuration = & node.exe --input-type=module -e "import {env,corsOrigins} from './dist/config/env.js'; console.log(JSON.stringify({port:env.PORT,origins:corsOrigins}));"
    if ($LASTEXITCODE -ne 0) { throw 'Backend configuration is incomplete.' }
    $settings = $configuration | ConvertFrom-Json
} finally { Pop-Location }
function Read-Health([string]$url) {
    try { return Invoke-RestMethod -Uri $url -TimeoutSec 2 } catch { return $null }
}
$apiUrl = "http://127.0.0.1:$($settings.port)"
$health = Read-Health "$apiUrl/health"
if ($health -and $health.data.service -ne 'movetraq-backend') {
    throw "Port $($settings.port) belongs to another service. Choose a free PORT in backend/.env."
}
$oldOrigins = $env:CORS_ORIGINS
$oldApiUrl = $env:VITE_API_URL
try {
    $env:CORS_ORIGINS = (@($settings.origins) + @('http://localhost:5173', 'http://127.0.0.1:5173') | Select-Object -Unique) -join ','
    $env:VITE_API_URL = "$apiUrl/api/v1"
    if (!$health) {
        $backendProcess = Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList 'dist/server.js' -WorkingDirectory $backendPath -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $backendPath 'local-server-out.log') -RedirectStandardError (Join-Path $backendPath 'local-server-error.log')
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 500
            $health = Read-Health "$apiUrl/health"
            if ($health) { break }
            $backendProcess.Refresh()
            if ($backendProcess.HasExited) { break }
        }
        if (!$health -or $health.data.service -ne 'movetraq-backend') {
            throw 'MoveTraq API did not start. Check backend/local-server-error.log; another process may occupy its port.'
        }
    }
    try { $page = Invoke-WebRequest -Uri 'http://127.0.0.1:5173' -UseBasicParsing -TimeoutSec 2 } catch { $page = $null }
    if ($page -and $page.Content -notmatch '<title>MoveTraq Admin</title>') {
        throw 'Port 5173 belongs to another website. Start the admin manually on a free port.'
    }
    if (!$page) {
        Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList @('node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '5173', '--strictPort') -WorkingDirectory $adminPath -WindowStyle Hidden -RedirectStandardOutput (Join-Path $adminPath 'local-dev-out.log') -RedirectStandardError (Join-Path $adminPath 'local-dev-error.log') | Out-Null
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 500
            try { $page = Invoke-WebRequest -Uri 'http://127.0.0.1:5173' -UseBasicParsing -TimeoutSec 2 } catch { $page = $null }
            if ($page) { break }
        }
        if (!$page) { throw 'Admin did not start. Check admin/local-dev-error.log.' }
    }
} finally {
    $env:CORS_ORIGINS = $oldOrigins
    $env:VITE_API_URL = $oldApiUrl
}
Write-Host 'Admin: http://127.0.0.1:5173'
Write-Host "API health: $apiUrl/health"
