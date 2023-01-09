###############################i
## REGISTER DMAAS AWS SOURCE ##
###############################

#Import Modules
Import-Module AWS.Tools.Common
Import-Module AWS.Tools.CloudFormation

#Variables
$dmaasUsername = "username as email"
$dmaasRegion = "us-west-2"
$dmaasApiKey = "Enter API Key"
$awsRegion = "us-west-2"
$awsAccountNumber = "Enter Account Number"
$awsAccessKeyId = "Enter Access Key"
$awsSecretAccessKey = "Enter Secret Key"
$awsResourceGroup = "Enter Any name"
$heliosApiUrlv1 = "https://helios.cohesity.com/irisservices/api/v1"
$heliosApiUrlv2 = "https://helios.cohesity.com/v2"

#Create and set AWS profile
Write-Output "`nConnecting to AWS ..."
Set-AWSCredentials -AccessKey $awsAccessKeyId -SecretKey $awsSecretAccessKey -StoreAs $awsResourceGroup
Initialize-AWSDefaultConfiguration -ProfileName $awsResourceGroup -Region $awsRegion
Write-Output "   Connected to AWS"

#Create authorized header with no region
$dmaasAuthorizedHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$dmaasAuthorizedHeader.Add("apiKey", "$dmaasApiKey")
$dmaasAuthorizedHeader.Add("accept", "application/json")

#Get tenant ID
Write-Output "`nDMaaS tenant information ..."
$response = Invoke-RestMethod -Method GET -Uri "$heliosApiUrlv1/mcm/userInfo" -Headers $dmaasAuthorizedHeader
$dmaasTenantId = $response.user.profiles.tenantId
Write-Output "   DMaaS tenant ID: $dmaasTenantId"
Write-Output "   DMaaS region: $dmaasRegion"

#Create region authorized header
$dmaasRegionAuthorizedHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$dmaasRegionAuthorizedHeader.Add("apiKey", "$dmaasApiKey")
$dmaasRegionAuthorizedHeader.Add("accept", "application/json")
$dmaasRegionAuthorizedHeader.Add("regionId", "$dmaasRegion")

#Register AWS source
Write-Output "`nRegistering AWS source ..."
$dmaasTenantIdProcessed = $dmaasTenantId -Replace("/","%2F")
$dmaasTenantIdProcessed = $dmaasTenantIdProcessed -Replace(":","%3A")
$payload = @{
    "useCases" = @("EC2","RDS");
    "tenantId" = "$dmaasTenantId";
    "destinationRegionId" = "$awsRegion";
    "awsAccountNumber" = "$awsAccountNumber";
} | ConvertTo-Json -Depth 4
$response = Invoke-RestMethod -Method POST -Uri "$heliosApiUrlv2/mcm/dms/tenants/regions/aws-cloud-source" -Headers $dmaasRegionAuthorizedHeader -ContentType "application/json" -Body $payload
$response = Invoke-RestMethod -Method GET -Uri "$heliosApiUrlv2/mcm/dms/tenants/regions/aws-cloud-source?tenantId=$dmaasTenantIdProcessed&destinationRegionId=$awsRegion&awsAccountNumber=$awsAccountNumber" -Headers $dmaasRegionAuthorizedHeader
$awsIamRoleArn = $response.awsIamRoleArn
$awsTenantCpRoleArn = $response.tenantCpRoleArn
$awsCloudFormationTemplate = $response.cloudFormationTemplate
Start-Sleep 10
New-CFNStack -StackName "dms$awsResourceGroupNumber" -TemplateBody $awsCloudFormationTemplate -OnFailure "ROLLBACK" -Capability CAPABILITY_NAMED_IAM
Write-Output "   AWS Cloud Formation stack deployment in progress (this takes roughly 2-3 minutes)"
$response = Get-CFNStack -StackName "dms$awsResourceGroupNumber"
$awsCfStackStatus = $response.StackStatus.Value
Write-Output "   AWS Cloud Formation Stack Deployment Status: $awsCfStackStatus"
[int]$timer = 0
while ($awsCfStackStatus -match "CREATE_IN_PROGRESS") {
    $response = Get-CFNStack -StackName "dms$awsResourceGroupNumber"
    $awsCfStackStatus = $response.StackStatus.Value
    if ($awsCfStackStatus -match "CREATE_COMPLETE") {
        Write-Output "   Cloud Formation stack deployment complete ($awsCfStackStatus)"
        break
    }
    Start-Sleep 10
    $timer = $timer + 10
    Write-Output "   Waiting for Cloud Formation stack to deploy ($awsCfStackStatus): $timer seconds elapsed"
}
Write-Output "`nVerifying cloud connection from DMaaS tenant ..."
$verified = 0
[int]$timer = 0
while ($verified -eq 0) {
    $er = 0
    try {
        $response = Invoke-RestMethod -Method GET -Uri "$heliosApiUrlv2/mcm/dms/tenants/regions/aws-cloud-source-verify?tenantId=$dmaasTenantIdProcessed&destinationRegionId=$awsRegion&awsAccountNumber=$awsAccountNumber" -Headers $dmaasRegionAuthorizedHeader
    } catch {
        $er = 1
        Start-Sleep 10
        $timer = $timer + 10
        Write-Output "   Waiting for cloud connection verification: $timer seconds elapsed"
    }
    if ($er -eq 0) {
        $verified = 1
        Write-Output "   Cloud connection verified"
        break
    }
}
Start-Sleep 10
$payload = @{
    "environment" = "kAWS";
    "awsParams" = @{
        "subscriptionType" = "kAWSCommercial";
        "standardParams" = @{
            "authMethodType" = "kUseIAMRole";
            "iamRoleAwsCredentials" = @{
                "iamRoleArn" = "$awsIamRoleArn";
                "cpIamRoleArn" = "$awsTenantCpRoleArn";
            }
        }
    }
} | ConvertTo-Json -Depth 50
$response = Invoke-RestMethod -Method POST -Uri "$heliosApiUrlv2/mcm/data-protect/sources/registrations" -Headers $dmaasRegionAuthorizedHeader -ContentType "application/json" -Body $payload
$awsId = $response.id
Write-Output "   AWS Source ID: $awsId"
Write-Output "   Registered AWS source"
