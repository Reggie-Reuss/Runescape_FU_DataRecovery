$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb26.json'
$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Host "File size: $($bytes.Length) bytes"
Write-Host "First 4 bytes hex: $([BitConverter]::ToString($bytes[0..3]))"
Write-Host "Last 4 bytes hex: $([BitConverter]::ToString($bytes[($bytes.Length-4)..($bytes.Length-1)]))"

# Find first null byte
$firstNull = -1
for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 0x00) { $firstNull = $i; break }
}
Write-Host "First null byte at: $firstNull"

# Find any non-UTF8 bytes (values > 127 that form invalid sequences)
$invalidBytes = @()
$i = 0
while ($i -lt [Math]::Min($bytes.Length, 2000000)) {
    $b = $bytes[$i]
    if ($b -gt 0x7F) {
        # Multi-byte UTF-8 sequence
        $seqLen = if ($b -ge 0xF0) { 4 } elseif ($b -ge 0xE0) { 3 } elseif ($b -ge 0xC0) { 2 } else { 1 }
        if ($seqLen -eq 1) {
            # Continuation byte without lead - invalid
            $invalidBytes += $i
        }
        $i += $seqLen
    } else {
        $i++
    }
}
Write-Host "Invalid UTF-8 sequences found: $($invalidBytes.Count)"
if ($invalidBytes.Count -gt 0 -and $invalidBytes.Count -le 10) {
    foreach ($pos in $invalidBytes) {
        $ctx = [System.Text.Encoding]::Latin1.GetString($bytes[[Math]::Max(0,$pos-20)..([Math]::Min($bytes.Length-1,$pos+20))])
        Write-Host "  Position $pos (0x$($pos.ToString('X'))): byte=0x$($bytes[$pos].ToString('X2')) context=[$ctx]"
    }
}
Write-Host "File appears to be: $(if ($firstNull -eq -1 -and $invalidBytes.Count -eq 0) { 'Clean UTF-8' } elseif ($firstNull -gt 0) { 'Has null bytes' } else { 'Has encoding issues' })"
