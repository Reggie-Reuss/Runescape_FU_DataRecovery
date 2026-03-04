$basePath = 'C:\Users\Reggie\github\RL_FU_DataRecovery'
$raw = [System.IO.File]::ReadAllText("$basePath\RunescapeUsername.merged.json")

# Fix all 15 unknown item names
$nameFixes = @{
    30753 = "Oathplate chest"
    31163 = "Bloodbark armour set"
    31139 = "Blue moon armour set"
    31106 = "Confliction gauntlets"
    28307 = "Ultor ring"
    30085 = "Hueycoatl hide"
    29090 = "Calcified moth"
    30895 = "Steel ring"
    30756 = "Oathplate legs"
    30750 = "Oathplate helm"
    24251 = "Wilderness crabs teleport"
    13190 = "Old school bond"
    32889 = "Lead bar"
    31432 = "Camphor plank"
    30765 = "Oathplate shards"
}

foreach ($id in $nameFixes.Keys) {
    $old = "Unknown Item $id"
    $new = $nameFixes[$id]
    $raw = $raw.Replace("`"name`":`"$old`"", "`"name`":`"$new`"")
    Write-Host "Fixed: $old -> $new"
}

# Add "version":1 at the beginning (right after the opening brace)
if (-not $raw.Contains('"version"')) {
    $raw = $raw.Replace('{"accumulatedSessionTimeMillis"', '{"version":1,"accumulatedSessionTimeMillis"')
    Write-Host "Added version:1"
} else {
    Write-Host "version key already present"
}

# Save final file
$outPath = "$basePath\RunescapeUsername.merged.json"
[System.IO.File]::WriteAllText($outPath, $raw, [System.Text.Encoding]::UTF8)

# Validate
$check = [System.IO.File]::ReadAllText($outPath) | ConvertFrom-Json
$unknowns = ($check.trades | Where-Object { $_.name -like 'Unknown*' }).Count
Write-Host ""
Write-Host "=== Final validation ==="
Write-Host "JSON valid: True"
Write-Host "Version: $($check.version)"
Write-Host "Total trades: $($check.trades.Count)"
Write-Host "Remaining unknowns: $unknowns"
Write-Host "File size: $((Get-Item $outPath).Length) bytes"

# Count total offers
$totalOffers = 0
foreach ($t in $check.trades) { $totalOffers += @($t.h.sO).Count }
Write-Host "Total slot offers: $totalOffers"
