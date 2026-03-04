$files = @(
    'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.recovered-feb25.json',
    'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb26.json'
)

foreach ($path in $files) {
    Write-Host "=== $([System.IO.Path]::GetFileName($path)) ==="
    $bytes = [System.IO.File]::ReadAllBytes($path)
    Write-Host "Size: $($bytes.Length) bytes"
    Write-Host "First 8 bytes: $([BitConverter]::ToString($bytes[0..7]))"
    Write-Host "First chars: $([System.Text.Encoding]::Latin1.GetString($bytes[0..30]))"

    # Find first null byte
    $firstNull = -1
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 0x00) { $firstNull = $i; break }
    }
    Write-Host "First null byte at: $firstNull"

    if ($firstNull -gt 100) {
        # There's meaningful data before nulls - check how much total valid data
        # Count consecutive data blocks
        $validTotal = 0
        $inNull = ($bytes[0] -eq 0x00)
        $blockStart = 0
        $dataBlocks = 0
        for ($i = 1; $i -lt [Math]::Min($bytes.Length, 500000); $i++) {
            $isNull = ($bytes[$i] -eq 0x00)
            if ($isNull -ne $inNull) {
                if (-not $inNull) {
                    $validTotal += ($i - $blockStart)
                    $dataBlocks++
                }
                $inNull = $isNull
                $blockStart = $i
            }
        }
        Write-Host "Valid data in first 500KB: $validTotal bytes across $dataBlocks blocks"
    }

    # Check if it's valid JSON at start
    if ($firstNull -gt 10) {
        $startText = [System.Text.Encoding]::UTF8.GetString($bytes[0..([Math]::Min(200,$firstNull-1))])
        Write-Host "Start: $startText"
    }
    Write-Host ""
}

# Also check if ShadowCopy2 has a different backup file
Write-Host "=== Checking ShadowCopy2 backup size ==="
$sc2backup = '\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy2\Users\Reggie\.runelite\flipping\RunescapeUsername.backup.json'
try {
    $b = [System.IO.File]::ReadAllBytes($sc2backup)
    Write-Host "ShadowCopy2 backup size: $($b.Length) bytes"
    Write-Host "First chars: $([System.Text.Encoding]::Latin1.GetString($b[0..50]))"
} catch {
    Write-Host "Could not read ShadowCopy2 backup: $_"
}
