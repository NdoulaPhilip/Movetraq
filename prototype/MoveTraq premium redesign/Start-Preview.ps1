$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
Write-Host 'Movetraq preview: http://localhost:4173/MoveTraq.dc.html'
Write-Host 'Open that address in your browser. This UI preview needs no location permission.'
Write-Host 'Keep this terminal open. Press Ctrl+C to stop.'
python -m http.server 4173 --bind 127.0.0.1

