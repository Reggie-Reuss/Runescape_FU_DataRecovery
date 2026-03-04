$path = 'C:\Users\Reggie\.runelite\flipping\RunescapeUsername.recovered-feb25.json'
$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Host "File size: $($bytes.Length) bytes"
Write-Host "First 4 bytes hex: $([BitConverter]::ToString($bytes[0..3]))"
Write-Host "Last 4 bytes hex: $([BitConverter]::ToString($bytes[($bytes.Length-4)..($bytes.Length-1)]))"
Write-Host "First char: $([char]$bytes[0])"
Write-Host "Last char: $([char]$bytes[$bytes.Length-1])"

# Try parsing as UTF-8
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
Write-Host "UTF8 decode OK, length: $($text.Length)"
Write-Host "Starts with: $($text.Substring(0, 20))"
Write-Host "Ends with: $($text.Substring($text.Length - 30))"
