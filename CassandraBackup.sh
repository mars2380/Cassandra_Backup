#!/bin/bash
#
# Backup to AWS S3
# written by alessandro.dimicoli@researchresearch.com - July 2016
#
# NOTES Run "aws configure --profile Backups_Account"
 
BUCKET=researchresearch-live-cassandra-backups
DATE=$(date +%Y_%m_%d_%H_%M)
FOLDER=/mnt/cassandra/data/
DAY=$(date +%u)
### SERVER=$(curl ipinfo.io/hostname)
SERVER=ec2-11-11-111-123.eu-west-1.compute.amazonaws.com
AWSPROFILE=Backups_Account

KEYSPACES=database

function AWS_CHECK {
if [ "$?" -ne "0" ]; then
	echo "Upload to S3 Bucket failed" 
else
	echo "Upload to S3 Bucket has been completed" 
fi
}

function MAIL {
TO="admin@domain.com"
FROM="cassandra@domain.com"
SUBJECT="Cassandra S3 Backup"
MESSAGE=$(cat casS3backup.log)

date="$(date -R)"
priv_key="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" ### SNS_User Access key ID
access_key="YYYYYYYYYYYYYYYYYYYYYYYYY" ### SNS_User Secret access key
signature="$(echo -n "$date" | openssl dgst -sha256 -hmac "$priv_key" -binary | base64 -w 0)"
auth_header="X-Amzn-Authorization: AWS3-HTTPS AWSAccessKeyId=$access_key, Algorithm=HmacSHA256, Signature=$signature"
endpoint="https://email.eu-west-1.amazonaws.com/"
content_type="Content-Type: text/plain"
content_type="application/x-www-form-urlencoded"
mime_version="MIME-Version: 1.0"

action="Action=SendEmail"
source="Source=$FROM"
to="Destination.ToAddresses.member.1=$TO"
subject="Message.Subject.Data=$SUBJECT"
message="Message.Body.Text.Data=$MESSAGE"

curl -v -k -X POST -H "Date: $date" -H "$auth_header" --data-urlencode "$message" --data-urlencode "$to" --data-urlencode "$source" --data-urlencode "$action" --data-urlencode "$subject" --data-urlencode "backups.log" "$endpoint"
}

echo "Create Schema for all keyspaces"
for KEYSPACE in $KEYSPACES; do

cqlsh -e "DESCRIBE KEYSPACE $KEYSPACE" > $KEYSPACE.cql

echo "Archive $KEYSPACE keyspace"
sudo find $FOLDER -type d -name $KEYSPACE -execdir zip -q -r '{}'.gz '{}' \;

echo "Encrypte $KEYSPACE archive"
GZFILE=$(sudo find $FOLDER -type f -name $KEYSPACE.gz)

        for GPGFILE in $GZFILE; do
	
        sudo gpg -e -r ServerAdmin $GPGFILE ## Encrypt
	
	echo "Send $KEYSPACE to $BUCKET S3 Bucket"
        /usr/local/bin/aws s3 --profile $AWSPROFILE --quiet cp $GPGFILE.gpg s3://$BUCKET/$SERVER/$DATE$GPGFILE.gpg ## Send Snapshot to S3 Bucket

	AWS_CHECK	

	echo "Send $KEYSPACE schema to $BUCKET S3 Bucket"
        /usr/local/bin/aws s3 --profile $AWSPROFILE --quiet cp $KEYSPACE.cql s3://$BUCKET/$SERVER/$DATE/ ## Send Schema to S3 Bucket
	AWS_CHECK
                ## Sync Backup for mykeyspaces in $KEY; dop with Storage Folder
                if [ $DAY = 1 ]; then
                /usr/local/bin/aws --profile $AWSPROFILE s3 sync --quiet s3://$BUCKET/$SERVER/$DATE s3://$BUCKET/backupstorage/$SERVER/$DATE/
                AWS_CHECK
		fi
        done

done

echo "Clean up files"
sudo find $FOLDER -type f \( -name "*gpg" -o -name "*gz" \) -exec rm {} \; ## Be careful with this

MAIL
