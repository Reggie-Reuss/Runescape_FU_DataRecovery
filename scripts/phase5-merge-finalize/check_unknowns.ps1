$raw = [System.IO.File]::ReadAllText('C:\Users\Reggie\github\RL_FU_DataRecovery\RunescapeUsername.merged.json')
$data = $raw | ConvertFrom-Json
Write-Host "=== Unknown items ==="
$data.trades | Where-Object { $_.name -like 'Unknown Item*' } | ForEach-Object {
    Write-Host "id=$($_.id) name=$($_.name) offers=$(@($_.h.sO).Count)"
}

Write-Host ""
Write-Host "=== Current FU file format ==="
$fuCurrent = [System.IO.File]::ReadAllText('C:\Users\Reggie\.runelite\flipping\RunescapeUsername.json')
Write-Host "First 500 chars:"
Write-Host $fuCurrent.Substring(0, [Math]::Min(500, $fuCurrent.Length))
Write-Host ""
Write-Host "Has 'version' key: $($fuCurrent.Contains('"version"'))"
