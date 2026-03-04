$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'
$outPath = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.partial-restore.json'

$bytes = [System.IO.File]::ReadAllBytes($path)
$validBytes = $bytes[0..8191]
$text = [System.Text.Encoding]::UTF8.GetString($validBytes)

# Find the "trades":[ start
$tradesStart = $text.IndexOf('"trades":[')
Write-Host "trades array starts at: $tradesStart"

if ($tradesStart -eq -1) {
    Write-Host "No trades array found in partial data"
    exit
}

# Extract just the trades portion
$tradesContent = $text.Substring($tradesStart + 9) # skip "trades":

# Find the last COMPLETE trade entry (ends with },{ or }] )
# We'll find all the trade objects by finding complete {...} pairs
$depth = 0
$lastCompleteEnd = -1
$inString = $false
$escape = $false

for ($i = 1; $i -lt $tradesContent.Length; $i++) {
    $c = $tradesContent[$i]
    if ($escape) { $escape = $false; continue }
    if ($c -eq '\' -and $inString) { $escape = $true; continue }
    if ($c -eq '"' -and -not $escape) { $inString = -not $inString; continue }
    if ($inString) { continue }
    if ($c -eq '{') { $depth++ }
    if ($c -eq '}') {
        $depth--
        if ($depth -eq 0) {
            # This closes a top-level trade object
            $lastCompleteEnd = $i
        }
    }
}

Write-Host "Last complete trade entry ends at offset: $lastCompleteEnd (within trades array)"

if ($lastCompleteEnd -gt 0) {
    $completeTrades = $tradesContent.Substring(0, $lastCompleteEnd + 1)
    # completeTrades is now "[{...},{...}]" or "[{...},{...}"
    # Count complete trades
    $tradeCount = ([regex]::Matches($completeTrades, '"fB"')).Count
    Write-Host "Complete trade entries: $tradeCount"

    # Extract lastOffers section
    $loEnd = $text.IndexOf('"trades":')
    $lastOffersSection = $text.Substring(0, $loEnd).TrimEnd(',').TrimEnd()

    # Build valid JSON
    $json = $lastOffersSection + ',"trades":' + $completeTrades + '],"sessionStartTime":0,"accumulatedSessionTimeMillis":0,"slotTimers":[],"recipeFlipGroups":[],"lastStoredAt":0,"lastModifiedAt":0}'

    # Quick validation
    try {
        $parsed = $json | ConvertFrom-Json
        Write-Host "Output JSON is valid!"
        Write-Host "Trades in output: $($parsed.trades.Count)"
        Write-Host ""
        Write-Host "Items recovered:"
        $parsed.trades | ForEach-Object { Write-Host "  - $($_.name) (id: $($_.id))" }
    } catch {
        Write-Host "Output JSON invalid: $_"
        Write-Host "Last 100 chars of trades portion: $($completeTrades.Substring([Math]::Max(0,$completeTrades.Length-100)))"
    }

    # Save
    $outBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    [System.IO.File]::WriteAllBytes($outPath, $outBytes)
    Write-Host ""
    Write-Host "Saved to: $outPath"
}
