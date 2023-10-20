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
    "Processing region: ${region}" | Tee-Object -Append -FilePath $outputFile
    
    # Fetch S3 Buckets
    $buckets = Get-S3Bucket
    $bucketCount = $buckets.Count
    "Total number of S3 Buckets in region ${region}: $bucketCount" | Tee-Object -Append -FilePath $outputFile
    
    # Check for CloudWatch or S3 Analytics for S3 object count
    # Note: This is a simplified example; you'll need to add the actual API calls to fetch these metrics.
    $cloudWatchEnabled = $false
    $s3AnalyticsEnabled = $false
    if ($cloudWatchEnabled) {
        "CloudWatch is enabled. Fetching S3 object count from CloudWatch for region ${region}." | Tee-Object -Append -FilePath $outputFile
        # Fetch S3 object count from CloudWatch and log it
    } elseif ($s3AnalyticsEnabled) {
        "S3 Analytics is enabled. Fetching S3 object count from S3 Analytics for region ${region}." | Tee-Object -Append -FilePath $outputFile
        # Fetch S3 object count from S3 Analytics and log it
    } else {
        "Neither CloudWatch nor S3 Analytics is enabled for region ${region}." | Tee-Object -Append -FilePath $outputFile
    }

    # The rest of the script remains the same, gathering EC2, EBS, and RDS information
    # ...
}

"Output saved to file: $((Resolve-Path $outputFile).Path)" | Tee-Object -Append -FilePath $outputFile
