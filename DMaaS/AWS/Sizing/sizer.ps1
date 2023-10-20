# Check for AWSPowerShell module and install if not present
if (-Not (Get-Module -ListAvailable -Name AWSPowerShell)) {
    "AWSPowerShell module not found. Installing now..." | Out-File -Append "Cohesity_AWS_Sizing.txt"
    Install-Module -Name AWSPowerShell -Scope CurrentUser -Force -SkipPublisherCheck
}

# Import AWS module
Import-Module AWSPowerShell

# Prompt for AWS Credentials if not already set
if (-Not (Get-AWSCredential -ListProfileDetail)) {
    $accessKey = Read-Host -Prompt "Enter your AWS Access Key"
    $secretKey = Read-Host -Prompt "Enter your AWS Secret Key" -AsSecureString
    $region = Read-Host -Prompt "Enter your default AWS region (e.g., us-east-1)"
    Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKey -StoreAs default
    Initialize-AWSDefaults -ProfileName default -Region $region
}

# List of all AWS regions you want to check
$regions = @( 'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2', 'eu-west-1', 'eu-central-1' )  # Add more regions as needed

foreach ($region in $regions) {
    "-------- Region: ${region} --------" | Out-File -Append "Cohesity_AWS_Sizing.txt"

    # Initialize variables for S3
    $allBucketsSize = 0

    # Get list of all S3 Buckets in the current region
    $buckets = Get-S3Bucket | Where-Object { $_.Location.Value -eq $region }
    "Total number of S3 Buckets in ${region}: $($buckets.Count)" | Out-File -Append "Cohesity_AWS_Sizing.txt"

    # EC2 logic
    $ec2Instances = Get-EC2Instance -Region $region
    $runningInstanceIds = $ec2Instances | Where-Object { $_.Instances[0].State.Name -eq 'running' } | ForEach-Object { $_.Instances[0].InstanceId }
    $nonRunningInstanceIds = $ec2Instances | Where-Object { $_.Instances[0].State.Name -ne 'running' } | ForEach-Object { $_.Instances[0].InstanceId }

    "Total number of EC2 Instances in ${region}: $($ec2Instances.Count)" | Out-File -Append "Cohesity_AWS_Sizing.txt"
    "Number of running EC2 Instances in ${region}: $($runningInstanceIds.Count)" | Out-File -Append "Cohesity_AWS_Sizing.txt"
    "Number of non-running EC2 Instances in ${region}: $($nonRunningInstanceIds.Count)" | Out-File -Append "Cohesity_AWS_Sizing.txt"

    # EBS Logic
    $ebsVolumes = Get-EC2Volume -Region $region
    $ebsRunningTotalSize = 0
    $ebsNonRunningTotalSize = 0

    foreach ($volume in $ebsVolumes) {
        if ($runningInstanceIds -contains $volume.Attachment.InstanceId) {
            $ebsRunningTotalSize += $volume.Size
        } elseif ($nonRunningInstanceIds -contains $volume.Attachment.InstanceId) {
            $ebsNonRunningTotalSize += $volume.Size
        }
    }

    $ebsRunningTotalSizeTB = [math]::Round(($ebsRunningTotalSize / 1024), 2)
    $ebsNonRunningTotalSizeTB = [math]::Round(($ebsNonRunningTotalSize / 1024), 2)

    "Total size of EBS volumes attached to running instances in ${region}: $($ebsRunningTotalSizeTB) TB" | Out-File -Append "Cohesity_AWS_Sizing.txt"
    "Total size of EBS volumes attached to non-running instances in ${region}: $($ebsNonRunningTotalSizeTB) TB" | Out-File -Append "Cohesity_AWS_Sizing.txt"

    # RDS Logic
    $rdsInstances = Get-RDSDBInstance -Region $region
    $rdsEngineTypes = @{}
    $rdsTotalSize = 0
    foreach ($instance in $rdsInstances) {
        $engine = $instance.Engine
        $size = $instance.AllocatedStorage
        $rdsTotalSize += $size
        if ($rdsEngineTypes.ContainsKey($engine)) {
            $rdsEngineTypes[$engine] += $size
        } else {
            $rdsEngineTypes[$engine] = $size
        }
    }
    $rdsTotalSizeTB = [math]::Round(($rdsTotalSize / 1024), 2)
    "Total size of RDS Instances in ${region}: $($rdsTotalSizeTB) TB" | Out-File -Append "Cohesity_AWS_Sizing.txt"

    foreach ($key in $rdsEngineTypes.Keys) {
        $engineSizeTB = [math]::Round(($rdsEngineTypes[$key] / 1024), 2)
        "RDS Engine type $key in ${region} total size: $($engineSizeTB) TB" | Out-File -Append "Cohesity_AWS_Sizing.txt"
    }
}
