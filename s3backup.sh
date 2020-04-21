aws_profile=awscliprofile
 
backup_path=sharepath
 
bucket_name=s3bucketname
 
aws s3 sync  s3://$bucket_name $backup_path --profile=$aws_profile
