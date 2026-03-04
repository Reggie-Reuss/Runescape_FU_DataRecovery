$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'

$bytes = [System.IO.File]::ReadAllBytes($path)

# Find first null byte
$firstNull = -1
for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 0x00) {
        $firstNull = $i
        break
    }
}
Write-Host "First null byte at: $firstNull"

# Look at content just before null bytes
if ($firstNull -gt 100) {
    $start = [Math]::Max(0, $firstNull - 200)
    $snippet = [System.Text.Encoding]::UTF8.GetString($bytes[$start..($firstNull-1)])
    Write-Host "Content before nulls: [$snippet]"
}

# Also search for common FU end markers
$text = [System.Text.Encoding]::UTF8.GetString($bytes[0..([Math]::Min($firstNull+100, $bytes.Length-1))])
Write-Host "Searching for FU fields..."
foreach ($field in @('"lastInteraction"', '"sessionStartTime"', '"timeOfFirstOffer"', '"accountName"', '"totalGELimit"', '"startOfRefreshInterval"')) {
    $p = $text.LastIndexOf($field)
    if ($p -gt 0) { Write-Host "Found $field at $p" }
}
