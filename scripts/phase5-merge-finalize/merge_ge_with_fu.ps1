# Merge grand-exchange.json (3rd party GE history) with RunescapeUsername.restored-allblocks.json
# Output: RunescapeUsername.merged.json (valid FU format)

$basePath = 'C:\Users\Reggie\github\RL_FU_DataRecovery'

# --- 1. Load OSRS item mapping (id -> name, limit) ---
Write-Host "Loading OSRS item mapping..."
# PS5 can't handle 837KB JSON with ConvertFrom-Json easily, so parse with .NET
$mapRaw = [System.IO.File]::ReadAllText("$basePath\osrs_mapping.json")

# Build lookup hashtable: itemId -> {name, limit}
$itemMap = @{}
$mapMatches = [regex]::Matches($mapRaw, '"id":(\d+)[^}]*?"name":"([^"]*)"')
foreach ($m in $mapMatches) {
    $itemMap[[int]$m.Groups[1].Value] = $m.Groups[2].Value
}
# Also extract limits
$limitMatches = [regex]::Matches($mapRaw, '"id":(\d+)[^}]*?"limit":(\d+)')
$limitMap = @{}
foreach ($m in $limitMatches) {
    $limitMap[[int]$m.Groups[1].Value] = [int]$m.Groups[2].Value
}
Write-Host "  Loaded $($itemMap.Count) item names, $($limitMap.Count) GE limits"

# --- 2. Load the GE transaction data ---
Write-Host "Loading grand-exchange.json..."
$geRaw = [System.IO.File]::ReadAllText("$basePath\grand-exchange.json")
$geData = $geRaw | ConvertFrom-Json
Write-Host "  $($geData.Count) transactions loaded"

# --- 3. Load existing FU restored data ---
Write-Host "Loading RunescapeUsername.restored-allblocks.json..."
$fuRaw = [System.IO.File]::ReadAllText("$basePath\RunescapeUsername.restored-allblocks.json")
$fuData = $fuRaw | ConvertFrom-Json
Write-Host "  $($fuData.trades.Count) existing trades loaded"

# Build lookup of existing FU trades by item ID
$existingTrades = @{}
foreach ($t in $fuData.trades) {
    $existingTrades[$t.id] = $t
}

# --- 4. Group GE transactions by item ID ---
Write-Host "Grouping GE transactions by item..."
$geByItem = @{}
foreach ($tx in $geData) {
    $iid = $tx.itemId
    if (-not $geByItem[$iid]) { $geByItem[$iid] = @() }
    $geByItem[$iid] += $tx
}
Write-Host "  $($geByItem.Count) unique items in GE data"

# --- 5. Convert GE transactions to FU slot offers and merge ---
Write-Host "Converting and merging..."

function New-Uuid {
    return [guid]::NewGuid().ToString()
}

$newTradeCount = 0
$mergedOfferCount = 0
$newItemCount = 0

foreach ($iid in $geByItem.Keys) {
    $txList = $geByItem[$iid]

    # Convert each GE transaction to an FU slot offer
    $newOffers = @()
    foreach ($tx in $txList) {
        $state = if ($tx.buy) { "BOUGHT" } else { "SOLD" }
        $offer = [ordered]@{
            uuid           = (New-Uuid)
            b              = [bool]$tx.buy
            id             = [int]$tx.itemId
            cQIT           = [int]$tx.quantity
            p              = [int]$tx.price
            t              = [long]$tx.time
            s              = 0
            st             = $state
            tAA            = 1
            tSFO           = 0
            tQIT           = [int]$tx.quantity
            tradeStartedAt = ([long]$tx.time - 1000)
            beforeLogin    = $false
        }
        $newOffers += (New-Object PSObject -Property $offer)
        $mergedOfferCount++
    }

    if ($existingTrades.ContainsKey($iid)) {
        # Item exists in recovered data - append new offers to existing sO array
        $existing = $existingTrades[$iid]
        $existingSO = @($existing.h.sO)

        # Avoid duplicates: check by timestamp
        $existingTimes = @{}
        foreach ($so in $existingSO) {
            $existingTimes[$so.t] = $true
        }

        foreach ($no in $newOffers) {
            if (-not $existingTimes[$no.t]) {
                $existingSO += $no
            }
        }
        $existing.h.sO = $existingSO
    } else {
        # New item - create FU trade entry
        $itemName = $itemMap[$iid]
        if (-not $itemName) { $itemName = "Unknown Item $iid" }
        $geLimit = if ($limitMap.ContainsKey($iid)) { $limitMap[$iid] } else { 0 }

        $newTrade = [ordered]@{
            id           = [int]$iid
            name         = $itemName
            tGL          = [int]$geLimit
            h            = @{ sO = $newOffers }
            iBTLW        = 0
            pIB          = 1
            fB           = "RunescapeUsername"
            vFPI         = $true
            favorite     = $false
            favoriteCode = "1"
        }

        # Add to existing trades array
        $fuData.trades += (New-Object PSObject -Property $newTrade)
        $newItemCount++
    }
}

Write-Host ""
Write-Host "=== Merge Summary ==="
Write-Host "Existing recovered items: $($existingTrades.Count)"
Write-Host "New items from GE data:   $newItemCount"
Write-Host "Total slot offers added:  $mergedOfferCount"
Write-Host "Total items in merged:    $($fuData.trades.Count)"

# --- 6. Save merged file ---
$outPath = "$basePath\RunescapeUsername.merged.json"
$json = ConvertTo-Json $fuData -Depth 20 -Compress
[System.IO.File]::WriteAllText($outPath, $json, [System.Text.Encoding]::UTF8)

$fileSize = (Get-Item $outPath).Length
Write-Host ""
Write-Host "Saved: $outPath"
Write-Host "File size: $fileSize bytes ($([Math]::Round($fileSize/1024))KB)"

# Validate by re-loading
try {
    $check = [System.IO.File]::ReadAllText($outPath) | ConvertFrom-Json
    Write-Host "Validation: JSON valid, $($check.trades.Count) trades loaded"
} catch {
    Write-Host "Validation FAILED: $_"
}
