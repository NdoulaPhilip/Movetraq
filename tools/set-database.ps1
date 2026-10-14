$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot 'backend/.env'
if (!(Test-Path -LiteralPath $envPath)) { throw 'Configure backend/.env first.' }
$databasePassword = Read-Host 'Enter the saved MoveTraq Supabase database password' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($databasePassword)
try {
    $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if (!$passwordText) { throw 'The password cannot be empty.' }
    $encodedPassword = [Uri]::EscapeDataString($passwordText)
    $connectionLine = 'DATABASE_URL=postgresql://postgres.pxiznltjdgyvdkftzohf:' + $encodedPassword + '@aws-0-eu-west-2.pooler.supabase.com:5432/postgres'
    $envText = [IO.File]::ReadAllText($envPath)
    $envText = [Text.RegularExpressions.Regex]::Replace($envText, '(?m)^DATABASE_URL=.*$', [Text.RegularExpressions.MatchEvaluator]{ param($match) $connectionLine })
    [IO.File]::WriteAllText($envPath, $envText, [Text.UTF8Encoding]::new($false))
    Write-Host 'Database connection saved in backend/.env. The password was not printed.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $passwordText = $null
    $encodedPassword = $null
    $connectionLine = $null
    $databasePassword.Dispose()
}
