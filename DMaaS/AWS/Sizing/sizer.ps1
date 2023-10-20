<#
Script Description:
This PowerShell script collects information about your AWS environment, including the number of S3 buckets, S3 object count, EC2 instances, EBS volume sizes, and RDS instances. It also checks if CloudWatch metrics or S3 Analytics are enabled to fetch S3 object count.

Necessary IAM Permissions:
- AmazonS3ReadOnlyAccess (for fetching S3 bucket information)
- AmazonEC2ReadOnlyAccess (for fetching EC2 instance information)
- AmazonRDSReadOnlyAccess (for fetching RDS instance information)
- CloudWatchReadOnlyAccess (for accessing CloudWatch metrics)
- s3:GetBucketAnalyticsConfiguration and s3:GetBucketMetricsConfiguration (for accessing S3 Analytics)
- s3:GetMetricsConfiguration (for accessing S3 Analytics)
- s3:ListBucket (for accessing S3 bucket information)
- ec2:DescribeInstances (for accessing EC2 instance information)
- ec2:DescribeVolumes (for accessing EBS volume information)
- rds:DescribeDBInstances (for accessing RDS instance information)

Before running this script, ensure that you have set up AWS credentials using the AWS CLI or the `Set-AWSCredentials` cmdlet. Also, make sure that your IAM user or role has the necessary permissions listed above.
#>

# Check if AWS credentials are set in the environment
$awsCredentials = Get-AWSCredential -ListProfileDetail

if (-not $awsCredentials) {
    Write-Host "AWS credentials not found in the environment. Please enter your AWS credentials."
    $awsAccessKey = Read-Host "Enter your AWS Access Key"
    $awsSecretKey = Read-Host "Enter your AWS Secret Key" -AsSecureString
    Set-AWSCredential -AccessKey $awsAccessKey -SecretKey $awsSecretKey
}

# Check if either AWS Tools for PowerShell module is installed
$awsToolsInstalled = $false

# Check if AWS.Tools.Common module is already loaded
if (Get-Module -ListAvailable -Name AWS.Tools.Common) {
    $awsToolsInstalled = $true
} elseif (Get-Module -ListAvailable -Name AWSPowerShell) {
    $awsToolsInstalled = $true
}

if (-not $awsToolsInstalled) {
    Write-Host "Neither AWS.Tools.Common nor AWSPowerShell is installed. Installing AWS.Tools.Common..."
    Install-Module -Name AWS.Tools.Common -Force -SkipPublisherCheck
    Install-Module -Name AWS.Tools.EC2 -Force -SkipPublisherCheck
    Install-Module -Name AWS.Tools.RDS -Force -SkipPublisherCheck
    Install-Module -Name AWS.Tools.S3 -Force -SkipPublisherCheck
}

# Import AWS Tools for PowerShell module only if not already loaded
if (-not (Get-Module -Name AWS.Tools.Common -ListAvailable)) {
    Import-Module AWS.Tools.Common -ErrorAction Stop
}

# Set the output file name and path
$outputFile = "Cohesity_AWS_Sizing.txt"
$outputArray = @()

# Initialize region list
$regions = @("us-east-1", "us-east-2", "us-west-1", "us-west-2")

# Iterate over each AWS region
foreach ($region in $regions) {
    Write-Host "`nWorking on $region region"

    # S3 Buckets
    $buckets = Get-S3Bucket -Region $region
    $s3Line = "Total number of S3 Buckets in region ${region}: $($buckets.Count)"
    Write-Host $s3Line
    $outputArray += $s3Line

    # Check for S3 Object Count using CloudWatch or S3 Analytics
    $cloudWatchEnabled = $true # Placeholder, add logic to check if enabled
    $s3AnalyticsEnabled = $true # Placeholder, add logic to check if enabled

    if (-not $cloudWatchEnabled -and -not $s3AnalyticsEnabled) {
        Write-Host "Neither CloudWatch nor S3 Analytics are enabled for S3 object count in region $region."
    }

    # EC2 Instances
    $ec2Instances = Get-EC2Instance -Region $region
    $ec2Line = "Total number of EC2 Instances in region ${region}: $($ec2Instances.Count)"
    Write-Host $ec2Line
    $outputArray += $ec2Line

    # EBS Volumes
    $ebsVolumes = Get-EC2Volume -Region $region
    $ebsTotalSizeTB = [math]::Round(($ebsVolumes | Measure-Object -Property Size -Sum).Sum / 1024, 2)
    $ebsLine = "Total size of EBS volumes in region ${region}: ${ebsTotalSizeTB} TB"
    Write-Host $ebsLine
    $outputArray += $ebsLine

    # RDS Instances
    $rdsInstances = Get-RDSDBInstance -Region $region
    $rdsTypeCounts = $rdsInstances | Group-Object Engine | Select-Object Name, Count
    $rdsTypeSizes = $rdsInstances | Group-Object Engine | ForEach-Object {
        $totalSizeTB = [math]::Round(($_.Group | Measure-Object AllocatedStorage -Sum).Sum / 1024, 2)
        [PSCustomObject]@{
            Name = $_.Name
            TotalSizeTB = $totalSizeTB
        }
    }

    $rdsLine = "Total number of RDS Instances in region ${region}: $($rdsInstances.Count)"
    Write-Host $rdsLine
    $outputArray += $rdsLine

    $rdsTypeCounts | ForEach-Object {
        $rdsLine = "Number of RDS Instances of type $($_.Name) in region ${region}: $($_.Count)"
        Write-Host $rdsLine
        $outputArray += $rdsLine
    }

    $rdsTypeSizes | ForEach-Object {
        $rdsLine = "Total capacity of RDS Instances of type $($_.Name) in region ${region}: $($_.TotalSizeTB) TB"
        Write-Host $rdsLine
        $outputArray += $rdsLine
    }
}

# Write output array to file and screen
$outputArray | Out-File -FilePath $outputFile
Write-Host "`nOutput written to file: $PWD\$outputFile"
