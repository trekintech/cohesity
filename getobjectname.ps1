# Prompt user for API key
$apiKey = Read-Host -Prompt 'Enter API key'

# Prompt user for object ID
$objectId = Read-Host -Prompt 'Enter object ID'

# Prompt user for region ID
$regionId = Read-Host -Prompt 'Enter region ID'

# Send API request
Invoke-RestMethod -Method Get `
  -Uri 'https://helios.cohesity.com/v2/data-protect/objects' `
  -Headers @{
    'apiKey' = $apiKey;
    'Accept' = 'application/json';
    'regionId' = $regionId;
  } `
  -Body @{
    'ids' = $objectId;
    'onlyProtectedObjects' = 'true';
  } | Select-Object -ExpandProperty objects | Select-Object -ExpandProperty name
