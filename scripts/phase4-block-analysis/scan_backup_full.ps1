$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Host "Full scan of $($bytes.Length) bytes..."

# Find all non-null ranges
$inNull = ($bytes[0] -eq 0x00)
$start = 0
$ranges = @()

for ($i = 1; $i -lt $bytes.Length; $i++) {
    $isNull = ($bytes[$i] -eq 0x00)
    if ($isNull -ne $inNull) {
        $ranges += [PSCustomObject]@{Start=$start; End=$i-1; IsNull=$inNull; Length=($i-$start)}
        $start = $i; $inNull = $isNull
    }
}
$ranges += [PSCustomObject]@{Start=$start; End=$bytes.Length-1; IsNull=$inNull; Length=($bytes.Length-$start)}

$dataRanges = $ranges | Where-Object { -not $_.IsNull -and $_.Length -gt 50 }
Write-Host "Significant data ranges:"
foreach ($r in $dataRanges) {
    $snip = [System.Text.Encoding]::UTF8.GetString($bytes[$r.Start..([Math]::Min($r.End, $r.Start+80))])
    $snip = $snip -replace "[^\x20-\x7E]","?"
    Write-Host "  [$($r.Start)-$($r.End)] ($($r.Length) bytes): $snip"
}

# For each FU-looking data range, try to count trades
Write-Host ""
Write-Host "FU data analysis per block:"
foreach ($r in $dataRanges) {
    $text = [System.Text.Encoding]::UTF8.GetString($bytes[$r.Start..$r.End])
    if ($text -match '"trades"') {
        $tradeMatches = ([regex]::Matches($text, '"fB"')).Count
        $itemMatches = [regex]::Matches($text, '"name":"([^"]+)"')
        $names = ($itemMatches | ForEach-Object { $_.Groups[1].Value }) | Select-Object -Unique
        Write-Host ""
        Write-Host "  Block [$($r.Start)-$($r.End)] ($($r.Length) bytes) - FU DATA:"
        Write-Host "  Trade entries: $tradeMatches"
        Write-Host "  Item names ($($names.Count)): $($names -join ', ')"

        # Check if this block has valid JSON end
        $trimmed = $text.TrimEnd()
        Write-Host "  Ends with: ...$(if ($trimmed.Length -gt 50) { $trimmed.Substring($trimmed.Length-50) } else { $trimmed })"
    } elseif ($text.Length -gt 100) {
        Write-Host "  Block [$($r.Start)-$($r.End)] ($($r.Length) bytes) - NOT FU data: $($text.Substring(0,[Math]::Min(60,$text.Length)))"
    }
}
