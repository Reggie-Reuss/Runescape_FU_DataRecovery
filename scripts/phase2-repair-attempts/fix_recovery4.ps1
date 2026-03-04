$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)

# Check data distribution - find non-null byte ranges
$inNull = $false
$ranges = @()
$start = 0
for ($i = 0; $i -lt $bytes.Length; $i++) {
    $isNull = ($bytes[$i] -eq 0x00)
    if ($isNull -ne $inNull) {
        if ($i -gt $start) {
            $ranges += [PSCustomObject]@{ Start=$start; End=$i-1; IsNull=$inNull; Length=$i-$start }
        }
        $start = $i
        $inNull = $isNull
    }
    # Stop scanning after 50000 bytes for speed
    if ($i -gt 50000 -and $ranges.Count -gt 3) { Write-Host "(stopped scan at 50000)"; break }
}

Write-Host "Data ranges (first 20):"
$ranges | Select-Object -First 20 | ForEach-Object {
    if ($_.IsNull) {
        Write-Host "  NULL:  pos $($_.Start) - $($_.End) ($($_.Length) bytes)"
    } else {
        Write-Host "  DATA:  pos $($_.Start) - $($_.End) ($($_.Length) bytes)"
        if ($_.Length -gt 5) {
            $snip = [System.Text.Encoding]::UTF8.GetString($bytes[$_.Start..([Math]::Min($_.End, $_.Start+50))])
            Write-Host "          preview: [$snip]"
        }
    }
}
