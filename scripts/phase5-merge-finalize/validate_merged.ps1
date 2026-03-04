$basePath = 'C:\Users\Reggie\github\RL_FU_DataRecovery'
$raw = [System.IO.File]::ReadAllText("$basePath\RunescapeUsername.merged.json")
$data = $raw | ConvertFrom-Json

Write-Host "=== Merged file validation ==="
Write-Host "Top-level keys: $(($data | Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name }) -join ', ')"
Write-Host "Trades count: $($data.trades.Count)"
Write-Host ""

# Check a few items
Write-Host "=== Sample items (first 5) ==="
for ($i = 0; $i -lt [Math]::Min(5, $data.trades.Count); $i++) {
    $t = $data.trades[$i]
    $soCount = if ($t.h.sO) { @($t.h.sO).Count } else { 0 }
    Write-Host "  $($t.name) (id=$($t.id), tGL=$($t.tGL), sO=$soCount, fB=$($t.fB))"
}

# Check items that were merged (exist in both recovered + GE)
Write-Host ""
Write-Host "=== Items with most slot offers (likely merged) ==="
$sorted = $data.trades | Sort-Object { @($_.h.sO).Count } -Descending | Select-Object -First 10
foreach ($t in $sorted) {
    $soCount = @($t.h.sO).Count
    Write-Host "  $($t.name): $soCount offers"
}

# Check date range
Write-Host ""
Write-Host "=== Date range check ==="
$allTimes = @()
foreach ($t in $data.trades) {
    foreach ($so in @($t.h.sO)) {
        if ($so.t -gt 0) { $allTimes += $so.t }
    }
}
if ($allTimes.Count -gt 0) {
    $minT = ($allTimes | Measure-Object -Minimum).Minimum
    $maxT = ($allTimes | Measure-Object -Maximum).Maximum
    $minDate = [DateTimeOffset]::FromUnixTimeMilliseconds($minT).ToLocalTime().ToString('yyyy-MM-dd')
    $maxDate = [DateTimeOffset]::FromUnixTimeMilliseconds($maxT).ToLocalTime().ToString('yyyy-MM-dd')
    Write-Host "Earliest trade: $minDate"
    Write-Host "Latest trade:   $maxDate"
    Write-Host "Total slot offers: $($allTimes.Count)"
}

# Check "Unknown Item" count
$unknown = ($data.trades | Where-Object { $_.name -like "Unknown Item*" }).Count
Write-Host ""
Write-Host "Items with unknown names: $unknown"

# Check a newly-added GE item to verify format
Write-Host ""
Write-Host "=== Sample new GE item (full structure) ==="
$newItem = $data.trades | Where-Object { @($_.h.sO).Count -eq 1 } | Select-Object -First 1
if ($newItem) {
    Write-Host (ConvertTo-Json $newItem -Depth 10)
}
