$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)

# Blocks 5 and 6 start mid-item, but we can search for item name references nearby
# Item names only appear in the outer trade object header: {"id":N,"name":"X","tGL":...
# In block 5 & 6 we're deep inside h.sO arrays, no item names directly visible

# But let's check the full file for ALL item names at any position
Write-Host "=== All item names in ALL blocks ==="
$allBlocks = @(
    @{Start=0;       End=8191;    Label="Block1"},
    @{Start=57344;   End=65535;   Label="Block2"},
    @{Start=253952;  End=266239;  Label="Block3"},
    @{Start=524288;  End=528383;  Label="Block4"},
    @{Start=1179648; End=1187839; Label="Block5"},
    @{Start=1527808; End=1532612; Label="Block6"}
)

$allNames = @{}
foreach ($b in $allBlocks) {
    $text = [System.Text.Encoding]::UTF8.GetString($bytes[$b.Start..$b.End])
    $nameMatches = [regex]::Matches($text, '"name":"([^"]+)"')
    $blockNames = @()
    foreach ($m in $nameMatches) {
        $name = $m.Groups[1].Value
        if (-not $allNames[$name]) {
            $allNames[$name] = $b.Label
        }
        $blockNames += $name
    }
    Write-Host "$($b.Label): $($blockNames.Count) name refs, unique new: $(($blockNames | Select-Object -Unique | Where-Object { $true }).Count)"
    if ($blockNames.Count -gt 0) {
        $uniq = $blockNames | Select-Object -Unique
        foreach ($n in $uniq) { Write-Host "  - $n" }
    }
    Write-Host ""
}

Write-Host "Total unique item names across all blocks: $($allNames.Count)"
Write-Host ""
Write-Host "=== Checking blocks 5 and 6 for any item references ==="
foreach ($b in ($allBlocks | Where-Object { $_.Label -in @("Block5","Block6") })) {
    $text = [System.Text.Encoding]::UTF8.GetString($bytes[$b.Start..$b.End])
    $idMatches = [regex]::Matches($text, '"id":(\d+)')
    Write-Host "$($b.Label): $($idMatches.Count) id references, $($text.Length) chars"
    Write-Host "  First 300: $($text.Substring(0,[Math]::Min(300,$text.Length)) -replace '[^\x20-\x7E]','?')"
    Write-Host ""
    Write-Host "  Last 300: $($text.Substring([Math]::Max(0,$text.Length-300)) -replace '[^\x20-\x7E]','?')"
    Write-Host ""
}

Write-Host ""
Write-Host "=== Gap analysis - how much data is missing ==="
$sortedBlocks = $allBlocks | Sort-Object { $_.Start }
$prev = $null
$totalGap = 0
foreach ($b in $sortedBlocks) {
    if ($prev -ne $null) {
        $gap = $b.Start - ($prev.End + 1)
        $totalGap += $gap
        Write-Host "Gap between $($prev.Label) and $($b.Label): $gap bytes (~$([Math]::Round($gap/1024))KB)"
    }
    $prev = $b
}
Write-Host "Total missing data: $totalGap bytes (~$([Math]::Round($totalGap/1024))KB)"
Write-Host "Total recovered data: $(($allBlocks | ForEach-Object { $_.End - $_.Start + 1 } | Measure-Object -Sum).Sum) bytes"

# Estimate how many trades might have been in the missing data
# Average trade size based on what we recovered: 28823 chars for 67 trades = 430 chars/trade
$avgTradeSize = 430
$estimatedMissingTrades = [Math]::Round($totalGap / $avgTradeSize)
Write-Host ""
Write-Host "Avg trade size in recovered blocks: ~$avgTradeSize bytes"
Write-Host "Estimated trades in missing gaps: ~$estimatedMissingTrades"
Write-Host "(This doesn't include slot offer history - actual average per trade-item is likely higher)"
