$headers = @{
    'apiKey' = Read-Host -Prompt 'Enter apiKey'
    'Accept' = 'application/json'
}

$startTime = [datetime]::UtcNow.AddDays(-1)
$startTimeUsecs = [math]::Round((($startTime.ToUniversalTime() - [datetime]'1/1/1970 00:00:00').TotalMilliseconds * 1000), 0)

$params = @{
    'includeDmaasLogs' = 'true'
    'serviceContext[0]' = 'Dmaas'
    'startTimeUsecs' = [int64]$startTimeUsecs
}

$response = Invoke-RestMethod -Uri 'https://helios.cohesity.com/v2/mcm/audit-logs' -Method GET -Headers $headers -Body $params

$response.auditLogs | ConvertTo-Csv -NoTypeInformation | Out-File 'audit-logs.csv'
