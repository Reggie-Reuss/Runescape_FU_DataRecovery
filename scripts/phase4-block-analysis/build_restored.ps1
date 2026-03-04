$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)

$blockDefs = @(
    @{Start=0;       End=8191},
    @{Start=57344;   End=65535},
    @{Start=253952;  End=266239},
    @{Start=524288;  End=528383},
    @{Start=1179648; End=1187839},
    @{Start=1527808; End=1532612}
)

function Extract-CompleteTrades {
    param([string]$text, [int]$blockNum)
    $trades = @()
    $matches = [regex]::Matches($text, '\{"id":(\d+),"name":"([^"]+)"')
    foreach ($m in $matches) {
        $startPos = $m.Index
        $depth = 0; $inStr = $false; $esc = $false; $endPos = -1
        for ($i = $startPos; $i -lt $text.Length; $i++) {
            $c = $text[$i]
            if ($esc) { $esc = $false; continue }
            if ($c -eq '\' -and $inStr) { $esc = $true; continue }
            if ($c -eq '"' -and -not $esc) { $inStr = -not $inStr; continue }
            if ($inStr) { continue }
            if ($c -eq '{') { $depth++ }
            if ($c -eq '}') {
                $depth--
                if ($depth -eq 0) { $endPos = $i; break }
            }
        }
        if ($endPos -gt 0) {
            $tradeJson = $text.Substring($startPos, $endPos - $startPos + 1)
            $tMs = [regex]::Matches($tradeJson, '"t":(\d{13})')
            $lastTs = if ($tMs.Count -gt 0) { [long]$tMs[$tMs.Count-1].Groups[1].Value } else { 0 }
            $trades += [PSCustomObject]@{
                Id      = [int]$m.Groups[1].Value
                Name    = $m.Groups[2].Value
                Block   = $blockNum
                SoCount = ([regex]::Matches($tradeJson, '"uuid"')).Count
                Json    = $tradeJson
                LastTs  = $lastTs
            }
        }
    }
    return $trades
}

$allTrades = @()
for ($i = 0; $i -lt $blockDefs.Count; $i++) {
    $bd = $blockDefs[$i]
    $text = [System.Text.Encoding]::UTF8.GetString($bytes[$bd.Start..$bd.End])
    $extracted = Extract-CompleteTrades -text $text -blockNum ($i+1)
    Write-Host "Block $($i+1): $($extracted.Count) complete trades"
    $allTrades += $extracted
}

# Deduplicate: if same item name appears in multiple blocks, keep the one with most slot offers
$seen = @{}
$deduped = @()
foreach ($t in ($allTrades | Sort-Object -Property @{E={$_.SoCount}; D=$true})) {
    if (-not $seen[$t.Name]) {
        $deduped += $t
        $seen[$t.Name] = $true
    }
}

Write-Host ""
Write-Host "Total unique items recoverable: $($deduped.Count)"

# Build trades JSON array (PS5 compatible - no Join-String)
$tradeJsonParts = @()
foreach ($t in $deduped) {
    $tradeJsonParts += $t.Json
}
$tradesArray = '[' + ($tradeJsonParts -join ',') + ']'

# Get the lastOffers section from block 1
$block1 = [System.Text.Encoding]::UTF8.GetString($bytes[0..8191])
$tradesIdx = $block1.IndexOf('"trades":')
if ($tradesIdx -gt 0) {
    $lastOffersSection = $block1.Substring(0, $tradesIdx).TrimEnd(',').TrimEnd()
} else {
    $lastOffersSection = '{"lastOffers":{}}'
    Write-Host "WARNING: Could not locate trades: boundary in block 1"
}

# Build complete JSON using correct FU format
$finalJson = $lastOffersSection + ',"trades":' + $tradesArray + ',"sessionStartTime":0,"accumulatedSessionTimeMillis":0,"slotTimers":[],"recipeFlipGroups":[],"lastStoredAt":1771988086233,"lastModifiedAt":1708053179683}'

Write-Host "JSON length: $($finalJson.Length) chars"

# Validate
try {
    $parsed = $finalJson | ConvertFrom-Json
    Write-Host "JSON VALID - $($parsed.trades.Count) trades loaded"
    Write-Host ""
    Write-Host "Recovered items by date (most recent first):"
    $sorted = $parsed.trades | Sort-Object -Property @{E={
        $tM = [regex]::Matches(($_ | ConvertTo-Json -Depth 20), '"t":(\d{13})')
        if ($tM.Count -gt 0) { [long]$tM[0].Groups[1].Value } else { 0 }
    }; D=$true}
    $sorted | ForEach-Object { Write-Host "  $($_.name) (id=$($_.id))" }
} catch {
    Write-Host "JSON INVALID: $_"
    # Show where it likely fails
    $errIdx = $finalJson.IndexOf('trades":') + 10
    Write-Host "Near trades start: $($finalJson.Substring($errIdx, [Math]::Min(100, $finalJson.Length - $errIdx)))"
}

# Save
$outPath = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.restored-allblocks.json'
[System.IO.File]::WriteAllBytes($outPath, [System.Text.Encoding]::UTF8.GetBytes($finalJson))
Write-Host ""
Write-Host "Saved: $outPath"
Write-Host "File size: $([System.IO.File]::ReadAllBytes($outPath).Length) bytes"
