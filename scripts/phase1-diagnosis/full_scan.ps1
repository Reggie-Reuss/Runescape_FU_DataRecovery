$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Host "Scanning full $($bytes.Length) byte file..."

# Find ALL non-null ranges in the full file
$inNull = ($bytes[0] -eq 0x00)
$start = 0
$ranges = @()

for ($i = 1; $i -lt $bytes.Length; $i++) {
    $isNull = ($bytes[$i] -eq 0x00)
    if ($isNull -ne $inNull) {
        $ranges += [PSCustomObject]@{
            Start=$start; End=$i-1; IsNull=$inNull; Length=($i-$start)
        }
        $start = $i
        $inNull = $isNull
    }
}
$ranges += [PSCustomObject]@{Start=$start; End=$bytes.Length-1; IsNull=$inNull; Length=($bytes.Length-$start)}

Write-Host "Total ranges found: $($ranges.Count)"
Write-Host ""

# Show all non-null data ranges
$dataRanges = $ranges | Where-Object { -not $_.IsNull -and $_.Length -gt 10 }
Write-Host "Non-null data ranges (>10 bytes):"
foreach ($r in $dataRanges) {
    $snip = ""
    try {
        $snip = [System.Text.Encoding]::UTF8.GetString($bytes[$r.Start..([Math]::Min($r.End, $r.Start+60))])
        $snip = $snip -replace "`r`n|`n|`r", " "
    } catch {}
    Write-Host "  [$($r.Start) - $($r.End)] ($($r.Length) bytes): $snip"
}

Write-Host ""

# Also search for FU JSON markers anywhere in the file
Write-Host "Searching for FU JSON markers anywhere in file..."
$fullText = [System.Text.Encoding]::Latin1.GetString($bytes)  # Latin1 never fails
foreach ($marker in @('{"lastOffers"', '"lastModifiedAt"', '"lastStoredAt"', '"lastInteraction"', '"trades":[')) {
    $pos = 0
    $found = @()
    while ($true) {
        $p = $fullText.IndexOf($marker, $pos)
        if ($p -eq -1) { break }
        $found += $p
        $pos = $p + 1
        if ($found.Count -ge 5) { break }
    }
    if ($found.Count -gt 0) {
        Write-Host "  '$marker' found at positions: $($found -join ', ')"
    }
}

# Also check Feb 26 file for FU markers
Write-Host ""
Write-Host "Checking Feb 26 shadow file for FU markers..."
$path26 = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb26.json'
if (Test-Path $path26) {
    $b26 = [System.IO.File]::ReadAllBytes($path26)
    $t26 = [System.Text.Encoding]::Latin1.GetString($b26)
    Write-Host "Feb 26 file size: $($b26.Length) bytes"
    foreach ($marker in @('{"lastOffers"', '"lastModifiedAt"', '"lastStoredAt"', '"trades":[', '{"id":')) {
        $p = $t26.IndexOf($marker)
        if ($p -ge 0) {
            Write-Host "  FOUND '$marker' at position $p"
            $snip = $t26.Substring($p, [Math]::Min(80, $t26.Length - $p))
            Write-Host "  Preview: $snip"
        }
    }
}
