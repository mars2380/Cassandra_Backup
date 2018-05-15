#!/bin/bash
#
# Backup to AWS S3
# written by alessandro.dimicoli@researchresearch.com - July 2016
#
# NOTES Run "aws configure --profile Backups_Group" to make the script working.
# AWS Backups_Group credential in KeePass
# GPG Key are in KeePass
 
bucket=researchresearch-live-cassandra-backups
date=$(date +%Y_%m_%d_%H_%M)
dir=/mnt/cassandra/data/
day=$(date +%u)
servername=$(curl ipinfo.io/hostname)

## Find all keyspaces
KEY=$(cqlsh -e "DESC KEYSPACES" | tr -d '"')

## Take snapshot only for a specific Keyspace only for testing
nodetool -h localhost -p 7199 snapshot "OpsCenter" > snapshot_dir_list
for mykeyspaces in OpsCenter; do

## Create snapshot for all keyspaces
## for mykeyspaces in $KEY; do
## nodetool -h localhost -p 7199 snapshot $mykeyspaces > snapshot_dir_list

## Create Snapshot archive
echo "Create Snapshot archive for $mykeyspaces"

X=$(cat snapshot_dir_list | grep "Snapshot directory:" | awk '{print $3}')
sudo find $dir -type d -name $X -execdir zip -r '{}'.gz '{}' \;

## Encrypte archive and send to Bucket
gzfile=$(sudo find $dir -type f -name $X.gz)

        for gpgfile in $gzfile; do

	echo $gpgfile
        sudo gpg -e -r ServerAdmin $gpgfile ## Encrypt Snapshot

        /usr/local/bin/aws s3 --profile Backups_Group cp $gpgfile.gpg s3://$bucket/$servername/$date$gpgfile.gpg ## Send Snapshot to S3 Bucket

        if [ "$?" -ne "0" ]; then
        echo "Upload to AWS failed" 
        else
        echo "Upload to AWS has been completed with successful" 
        fi

                ## Sync Backufor mykeyspaces in $KEY; dop with Storage Folder
                if [ $day = 1 ]; then
		/usr/local/bin/aws --profile Backups_Group s3 sync --quiet s3://$bucket/$servername/$date s3://$bucket/backupstorage/$servername/$date/
                fi
        done

done

## clean up files
nodetool -h localhost -p 7199 clearsnapshot
rm snapshot_dir_list
