# Load AWS Module
Import-Module AWS.Tools.Common -ErrorAction Stop

# Prompt for AWS Credentials if not set
if (-Not (Test-Path $env:USERPROFILE\.aws\credentials)) {
    Initialize-AWSDefaultConfiguration -ProfileName default
}

# Define regions
$regions = @("us-east-1", "us-east-2", "us-west-1", "us-west-2")

# Initialize output file
$outputFile = "Cohesity_AWS_Sizing.txt"
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Loop through each AWS region
foreach ($region in $regions) {
    "Processing region: $region" | Tee-Object -Append -FilePath $outputFile
    
    # Fetch S3 Buckets
    $buckets = Get-S3Bucket
    "Total number of S3 Buckets in region $region: $($buckets.Count)" | Tee-Object -Append -FilePath $outputFile
    
    # Fetch EC2 Instances
    $ec2Instances = Get-EC2Instance -Region $region
    $runningEc2Instances = $ec2Instances | Where-Object {$_.Instances.State.Name -eq 'running'}
    $stoppedEc2Instances = $ec2Instances | Where-Object {$_.Instances.State.Name -ne 'running'}
    "Total number of running EC2 Instances in region $region: $($runningEc2Instances.Count)" | Tee-Object -Append -FilePath $outputFile
    "Total number of stopped EC2 Instances in region $region: $($stoppedEc2Instances.Count)" | Tee-Object -Append -FilePath $outputFile
    
    # Fetch EBS Volumes
    $ebsVolumes = Get-EC2Volume -Region $region
    $runningEbsTotalSize = ($ebsVolumes | Where-Object {$_.Attachments.State -eq 'attached'}).Size | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $stoppedEbsTotalSize = ($ebsVolumes | Where-Object {$_.Attachments.State -ne 'attached'}).Size | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    "Total size of attached EBS volumes in region $region: {0:N2} GB" -f ($runningEbsTotalSize / 1024) | Tee-Object -Append -FilePath $outputFile
    "Total size of detached EBS volumes in region $region: {0:N2} GB" -f ($stoppedEbsTotalSize / 1024) | Tee-Object -Append -FilePath $outputFile
    
    # Fetch RDS Instances
    $rdsInstances = Get-RDSDBInstance -Region $region
    $groupedRds = $rdsInstances | Group-Object -Property DBInstanceClass
    "Total number of RDS Instances in region $region: $($rdsInstances.Count)" | Tee-Object -Append -FilePath $outputFile
    foreach ($group in $groupedRds) {
        $totalSize = ($group.Group | Measure-Object -Property AllocatedStorage -Sum).Sum
        "RDS Instance Type: $($group.Name), Count: $($group.Count), Total size: {0:N2} GB" -f ($totalSize / 1024) | Tee-Object -Append -FilePath $outputFile
    }
}

"Output saved to file: $((Resolve-Path $outputFile).Path)" | Tee-Object -Append -FilePath $outputFile
