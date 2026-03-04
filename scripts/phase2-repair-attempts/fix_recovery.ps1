$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'
$outPath = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25-fixed.json'

$bytes = [System.IO.File]::ReadAllBytes($path)

# Find the last '}' byte (0x7D) in the file
$lastBrace = -1
for ($i = $bytes.Length - 1; $i -ge 0; $i--) {
    if ($bytes[$i] -eq 0x7D) {
        $lastBrace = $i
        break
    }
}

Write-Host "File size: $($bytes.Length) bytes"
Write-Host "Last closing brace at position: $lastBrace"
Write-Host "Bytes after last brace (null/garbage): $($bytes.Length - $lastBrace - 1)"

# Write trimmed file
$trimmed = $bytes[0..$lastBrace]
[System.IO.File]::WriteAllBytes($outPath, $trimmed)
Write-Host "Written trimmed file: $($trimmed.Length) bytes"

# Validate
$text = [System.Text.Encoding]::UTF8.GetString($trimmed)
try {
    $json = $text | ConvertFrom-Json
    $tradeCount = $json.trades.Count
    Write-Host "JSON valid!"
    Write-Host "Trades tracked: $tradeCount"
    Write-Host "Version: $($json.version)"
    $names = ($json.trades | Select-Object -First 10 | ForEach-Object { $_.name }) -join ', '
    Write-Host "First 10 items: $names"
} catch {
    Write-Host "JSON still invalid: $_"
    Write-Host "End of trimmed text: $($text.Substring($text.Length - 50))"
}
