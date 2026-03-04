$raw = Get-Content 'C:\Users\Reggie\github\RL_FU_DataRecovery\grand-exchange.json' -Raw
$data = $raw | ConvertFrom-Json
Write-Host "Total entries: $($data.Count)"
Write-Host "First entry: $(ConvertTo-Json $data[0] -Compress)"
Write-Host "Last entry: $(ConvertTo-Json $data[$data.Count-1] -Compress)"
$firstTs = [DateTimeOffset]::FromUnixTimeMilliseconds($data[0].time).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
$lastTs = [DateTimeOffset]::FromUnixTimeMilliseconds($data[$data.Count-1].time).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
Write-Host "Date range: $firstTs to $lastTs"
$uniqueItems = ($data | ForEach-Object { $_.itemId } | Sort-Object -Unique)
Write-Host "Unique item IDs: $($uniqueItems.Count)"
$buys = ($data | Where-Object { $_.buy -eq $true }).Count
$sells = ($data | Where-Object { $_.buy -eq $false }).Count
Write-Host "Buys: $buys, Sells: $sells"
