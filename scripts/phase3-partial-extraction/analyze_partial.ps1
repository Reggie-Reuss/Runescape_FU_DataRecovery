$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)

# Extract just the 8192 valid bytes
$validBytes = $bytes[0..8191]
$text = [System.Text.Encoding]::UTF8.GetString($validBytes)

Write-Host "=== Valid 8KB content ==="
Write-Host "Start: $($text.Substring(0, 80))"
Write-Host ""
Write-Host "End of data (last 200 chars): $($text.Substring([Math]::Max(0,$text.Length-200)))"
Write-Host ""

# Count item names mentioned in this partial data
$itemMatches = [regex]::Matches($text, '"name":"([^"]+)"')
Write-Host "Item names found in partial data:"
$seen = @{}
foreach ($m in $itemMatches) {
    $name = $m.Groups[1].Value
    if (-not $seen[$name]) {
        Write-Host "  - $name"
        $seen[$name] = $true
    }
}
Write-Host ""
Write-Host "Total unique items in partial 8KB: $($seen.Count)"

# Also check the Feb 26 shadow first 100 bytes
Write-Host ""
Write-Host "=== Feb 26 shadow first 100 bytes ==="
$path26 = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb26.json'
$bytes26 = [System.IO.File]::ReadAllBytes($path26)
Write-Host "First 30 bytes hex: $([BitConverter]::ToString($bytes26[0..29]))"
# Try Latin-1 decode
$latin = [System.Text.Encoding]::Latin1.GetString($bytes26[0..99])
Write-Host "First 100 as Latin-1: [$latin]"
