$path = 'C:\Users\Reggie\github\RL_FU_DataRecovery\RunescapeUsername.merged.json'
$raw = [System.IO.File]::ReadAllText($path)

# Add version:1 at the very start
$raw = $raw.Replace('{"lastOffers"', '{"version":1,"lastOffers"')

[System.IO.File]::WriteAllText($path, $raw, [System.Text.Encoding]::UTF8)

# Verify
$first100 = $raw.Substring(0, 100)
Write-Host "First 100 chars: $first100"

$check = $raw | ConvertFrom-Json
Write-Host "Version: $($check.version)"
Write-Host "Trades: $($check.trades.Count)"
Write-Host "File size: $((Get-Item $path).Length) bytes"
