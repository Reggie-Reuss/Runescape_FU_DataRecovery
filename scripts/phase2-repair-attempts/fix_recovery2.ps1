$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'
$outPath = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25-fixed.json'

$bytes = [System.IO.File]::ReadAllBytes($path)
$text = [System.Text.Encoding]::UTF8.GetString($bytes)

# The FU file ends with "lastModifiedAt":TIMESTAMP}
# Search for lastModifiedAt near the end
$marker = '"lastModifiedAt":'
$pos = $text.LastIndexOf($marker)
Write-Host "lastModifiedAt found at position: $pos"

if ($pos -gt 0) {
    # Find the closing } after this marker
    $closePos = $text.IndexOf('}', $pos)
    Write-Host "Closing brace after lastModifiedAt at: $closePos"
    Write-Host "Snippet: $($text.Substring($pos, [Math]::Min(60, $text.Length - $pos)))"

    # Write fixed file
    $cleanText = $text.Substring(0, $closePos + 1)
    $cleanBytes = [System.Text.Encoding]::UTF8.GetBytes($cleanText)
    [System.IO.File]::WriteAllBytes($outPath, $cleanBytes)
    Write-Host "Written fixed file: $($cleanBytes.Length) bytes"
    Write-Host "Last 80 chars: $($cleanText.Substring($cleanText.Length - 80))"

    # Validate
    try {
        $json = $cleanText | ConvertFrom-Json
        Write-Host "JSON VALID!"
        Write-Host "Trades tracked: $($json.trades.Count)"
        $names = ($json.trades | Select-Object -First 10 | ForEach-Object { $_.name }) -join ', '
        Write-Host "First 10 items: $names"
    } catch {
        Write-Host "Still invalid: $_"
    }
}
