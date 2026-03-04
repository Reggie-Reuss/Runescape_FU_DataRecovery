$path = 'C:\Users\Reggie\github\RL_FU_DataRecovery\RunescapeUsername.merged.json'
$raw = [System.IO.File]::ReadAllText($path)
$data = $raw | ConvertFrom-Json

# Black chinchompa item ID = 11959, GE limit = 250
$itemId = 11959
$itemName = "Black chinchompa"
$geLimit = 250

# Aug 27, 2025 - convert to unix ms (noon EST)
$ts = [DateTimeOffset]::new(2025, 8, 27, 12, 0, 0, [TimeSpan]::FromHours(-5)).ToUnixTimeMilliseconds()

$newOffer = [ordered]@{
    uuid           = [guid]::NewGuid().ToString()
    b              = $true
    id             = $itemId
    cQIT           = 25000
    p              = 2200
    t              = $ts
    s              = 0
    st             = "BOUGHT"
    tAA            = 1
    tSFO           = 0
    tQIT           = 25000
    tradeStartedAt = ($ts - 1000)
    beforeLogin    = $false
}

# Check if Black chinchompa already exists
$existing = $data.trades | Where-Object { $_.id -eq $itemId }
if ($existing) {
    $existing.h.sO += (New-Object PSObject -Property $newOffer)
    Write-Host "Added offer to existing '$itemName' entry"
} else {
    $newTrade = [ordered]@{
        id           = $itemId
        name         = $itemName
        tGL          = $geLimit
        h            = @{ sO = @((New-Object PSObject -Property $newOffer)) }
        iBTLW        = 0
        pIB          = 1
        fB           = "RunescapeUsername"
        vFPI         = $true
        favorite     = $false
        favoriteCode = "1"
    }
    $data.trades += (New-Object PSObject -Property $newTrade)
    Write-Host "Created new '$itemName' trade entry"
}

$json = ConvertTo-Json $data -Depth 20 -Compress
[System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
Write-Host "Saved. Total trades: $($data.trades.Count)"
