$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)

# The 6 known data blocks
$blocks = @(
    @{Start=0;       End=8191},
    @{Start=57344;   End=65535},
    @{Start=253952;  End=266239},
    @{Start=524288;  End=528383},
    @{Start=1179648; End=1187839},
    @{Start=1527808; End=1532612}
)

Write-Host "=== Block boundary analysis ==="
Write-Host ""

for ($i = 0; $i -lt $blocks.Count; $i++) {
    $b = $blocks[$i]
    $text = [System.Text.Encoding]::UTF8.GetString($bytes[$b.Start..$b.End])
    $len = $text.Length

    # Count FU trade indicators
    $tradeCount = ([regex]::Matches($text, '"fB"')).Count
    $uuidCount  = ([regex]::Matches($text, '"uuid"')).Count

    Write-Host "--- Block $($i+1) [$($b.Start)-$($b.End)] ($($b.End - $b.Start + 1) bytes) | fB=$tradeCount uuids=$uuidCount ---"
    Write-Host "  START: $($text.Substring(0, [Math]::Min(150, $len)) -replace '[^\x20-\x7E]','?')"
    Write-Host ""
    Write-Host "  END:   $($text.Substring([Math]::Max(0,$len-150)) -replace '[^\x20-\x7E]','?')"
    Write-Host ""
}

Write-Host ""
Write-Host "=== Checking if blocks connect (end of N -> start of N+1) ==="
Write-Host ""

# Show last 80 chars of each block and first 80 chars of next
for ($i = 0; $i -lt $blocks.Count - 1; $i++) {
    $b1 = $blocks[$i]
    $b2 = $blocks[$i+1]
    $t1 = [System.Text.Encoding]::UTF8.GetString($bytes[$b1.Start..$b1.End])
    $t2 = [System.Text.Encoding]::UTF8.GetString($bytes[$b2.Start..$b2.End])
    $end1 = $t1.Substring([Math]::Max(0,$t1.Length-80)) -replace '[^\x20-\x7E]','?'
    $start2 = $t2.Substring(0,[Math]::Min(80,$t2.Length)) -replace '[^\x20-\x7E]','?'
    Write-Host "Block $($i+1) end:   ...$end1"
    Write-Host "Block $($i+2) start: $start2..."
    Write-Host ""
}

Write-Host ""
Write-Host "=== Timestamp analysis per block ==="
for ($i = 0; $i -lt $blocks.Count; $i++) {
    $b = $blocks[$i]
    $text = [System.Text.Encoding]::UTF8.GetString($bytes[$b.Start..$b.End])
    # Find all "t": timestamps
    $tsMatches = [regex]::Matches($text, '"t":(\d{13})')
    if ($tsMatches.Count -gt 0) {
        $first = [long]$tsMatches[0].Groups[1].Value
        $last  = [long]$tsMatches[$tsMatches.Count-1].Groups[1].Value
        $firstDate = [DateTimeOffset]::FromUnixTimeMilliseconds($first).ToLocalTime().ToString("yyyy-MM-dd HH:mm")
        $lastDate  = [DateTimeOffset]::FromUnixTimeMilliseconds($last).ToLocalTime().ToString("yyyy-MM-dd HH:mm")
        Write-Host "Block $($i+1): $($tsMatches.Count) timestamps, first=$firstDate last=$lastDate"
    } else {
        Write-Host "Block $($i+1): no timestamps found"
    }
}
