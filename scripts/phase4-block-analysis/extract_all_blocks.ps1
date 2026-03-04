$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)

# The 6 known data blocks
$blockDefs = @(
    @{Start=0;       End=8191},
    @{Start=57344;   End=65535},
    @{Start=253952;  End=266239},
    @{Start=524288;  End=528383},
    @{Start=1179648; End=1187839},
    @{Start=1527808; End=1532612}
)

# Step 1: Concatenate blocks in order (they are sequential fragments)
# Blocks 1->2 directly connect, 3->4 directly connect
# Treat as ordered fragments of the same JSON

# Build a "stitched" string by joining all block texts with a gap marker
$blockTexts = @()
foreach ($bd in $blockDefs) {
    $blockTexts += [System.Text.Encoding]::UTF8.GetString($bytes[$bd.Start..$bd.End])
}

Write-Host "=== Extracting complete trade items from all blocks ==="
Write-Host ""

# Function to extract complete trade items from a JSON fragment
# Trades look like: {"id":..., "name":"...", "tGL":..., "h":{"sO":[...]}, ...}
# We look for the top-level trade structure in the trades array

function Extract-CompleteTrades {
    param([string]$text, [int]$blockNum)

    $trades = @()

    # Find all positions where a trade-item starts: {"id":number,"name":"
    $pattern = '\{"id":(\d+),"name":"([^"]+)"'
    $matches = [regex]::Matches($text, $pattern)

    foreach ($m in $matches) {
        $startPos = $m.Index
        # Track brace depth to find the end of this trade object
        $depth = 0
        $inStr = $false
        $esc = $false
        $endPos = -1

        for ($i = $startPos; $i -lt $text.Length; $i++) {
            $c = $text[$i]
            if ($esc) { $esc = $false; continue }
            if ($c -eq '\' -and $inStr) { $esc = $true; continue }
            if ($c -eq '"' -and -not $esc) { $inStr = -not $inStr; continue }
            if ($inStr) { continue }
            if ($c -eq '{') { $depth++ }
            if ($c -eq '}') {
                $depth--
                if ($depth -eq 0) {
                    $endPos = $i
                    break
                }
            }
        }

        if ($endPos -gt 0) {
            $tradeJson = $text.Substring($startPos, $endPos - $startPos + 1)
            $id = [int]$m.Groups[1].Value
            $name = $m.Groups[2].Value

            # Count slot offers in this trade
            $soCount = ([regex]::Matches($tradeJson, '"uuid"')).Count

            # Get date range of offers
            $tMatches = [regex]::Matches($tradeJson, '"t":(\d{13})')
            $firstTs = if ($tMatches.Count -gt 0) { [long]$tMatches[0].Groups[1].Value } else { 0 }
            $lastTs  = if ($tMatches.Count -gt 1) { [long]$tMatches[$tMatches.Count-1].Groups[1].Value } else { $firstTs }

            $trades += [PSCustomObject]@{
                Id       = $id
                Name     = $name
                Block    = $blockNum
                SoCount  = $soCount
                Json     = $tradeJson
                FirstTs  = $firstTs
                LastTs   = $lastTs
            }
        }
    }
    return $trades
}

$allTrades = @()
for ($i = 0; $i -lt $blockTexts.Count; $i++) {
    $extracted = Extract-CompleteTrades -text $blockTexts[$i] -blockNum ($i+1)
    Write-Host "Block $($i+1): extracted $($extracted.Count) complete trade items"
    foreach ($t in $extracted) {
        $fDate = if ($t.FirstTs -gt 0) { [DateTimeOffset]::FromUnixTimeMilliseconds($t.FirstTs).ToLocalTime().ToString("yyyy-MM-dd") } else { "unknown" }
        $lDate = if ($t.LastTs -gt 0) { [DateTimeOffset]::FromUnixTimeMilliseconds($t.LastTs).ToLocalTime().ToString("yyyy-MM-dd") } else { "unknown" }
        Write-Host "  id=$($t.Id) name='$($t.Name)' sO=$($t.SoCount) dates=$fDate..$lDate"
    }
    $allTrades += $extracted
    Write-Host ""
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Total complete trades extracted: $($allTrades.Count)"

# Check for duplicates (same id, same name appearing in multiple blocks)
$byName = $allTrades | Group-Object -Property Name
Write-Host "Unique item names: $($byName.Count)"
$dups = $byName | Where-Object { $_.Count -gt 1 }
if ($dups.Count -gt 0) {
    Write-Host "Duplicated items (appear in multiple blocks):"
    foreach ($d in $dups) {
        Write-Host "  '$($d.Name)' appears $($d.Count) times (blocks: $(($d.Group | ForEach-Object { $_.Block }) -join ','))"
    }
}

# Build final trades JSON array - deduplicate by keeping the one with the most slot offers
$dedupedTrades = @()
$seen = @{}
foreach ($t in ($allTrades | Sort-Object -Property @{Expression={$t.SoCount}; Descending=$true})) {
    if (-not $seen[$t.Name]) {
        $dedupedTrades += $t
        $seen[$t.Name] = $true
    }
}

Write-Host ""
Write-Host "After dedup: $($dedupedTrades.Count) trades"
Write-Host ""

# Build valid JSON
$tradesJson = '[' + ($dedupedTrades | ForEach-Object { $_.Json } | Join-String -Separator ',') + ']'

# Get lastOffers section from block 1 (it starts the file)
$block1Text = $blockTexts[0]
$tradesArrayStart = $block1Text.IndexOf('"trades":')
if ($tradesArrayStart -gt 0) {
    $lastOffersSection = $block1Text.Substring(0, $tradesArrayStart).TrimEnd(',').TrimEnd()
    Write-Host "lastOffers section length: $($lastOffersSection.Length) chars"
} else {
    $lastOffersSection = '{"lastOffers":{}'
    Write-Host "WARNING: Could not find trades array start in block 1"
}

# Build complete JSON
$finalJson = $lastOffersSection + ',"trades":' + $tradesJson + ',"sessionStartTime":0,"accumulatedSessionTimeMillis":0,"slotTimers":[],"recipeFlipGroups":[],"lastStoredAt":1771988086233,"lastModifiedAt":1708053179683}'

Write-Host "Final JSON length: $($finalJson.Length) chars"

# Validate
try {
    $parsed = $finalJson | ConvertFrom-Json
    Write-Host "JSON is VALID!"
    Write-Host "Trades count: $($parsed.trades.Count)"
    Write-Host ""
    Write-Host "All recovered items:"
    $parsed.trades | Sort-Object -Property name | ForEach-Object { Write-Host "  $($_.name) (id=$($_.id))" }
} catch {
    Write-Host "JSON validation failed: $_"
    Write-Host "Last 200 chars: $($finalJson.Substring([Math]::Max(0,$finalJson.Length-200)))"
}

# Save
$outPath = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.restored-allblocks.json'
$outBytes = [System.Text.Encoding]::UTF8.GetBytes($finalJson)
[System.IO.File]::WriteAllBytes($outPath, $outBytes)
Write-Host ""
Write-Host "Saved to: $outPath"
