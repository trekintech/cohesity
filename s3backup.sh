AWS_PROFILE=my-profile-name
BACKUP_PATH=/my/path/
BUCKETS=($(
	aws s3api list-buckets --query "Buckets[].Name" --profile=$AWS_PROFILE --output text
))

for BUCKET_NAME in "${BUCKETS[@]}"
do
	echo "Syncing ${BUCKET_NAME}...";
	aws s3 sync s3://$BUCKET_NAME $BACKUP_PATH/$BUCKET_NAME --profile=$AWS_PROFILE
done
