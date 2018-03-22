#!/bin/bash
#
# Backup to AWS S3
# written by adimicoli@hotmail.com - July 2016
#
bucket=mybucket-backups
date=$(date +%Y_%m_%d_%H_%M)
dir=/mnt/cassandra/data/
day=$(date +%u)
servername=$(curl ipinfo.io/hostname)

## Take snapshot only for a specific Keyspace only for testing
#nodetool -h localhost -p 7199 snapshot "OpsCenter" > snapshot_dir_list
#for mykeyspaces in OpsCenter; do

## Find all keyspaces
KEY=$(cqlsh -e "DESC KEYSPACES" | tr -d '"')

## Create snapshot for all keyspaces
for mykeyspaces in $KEY; do
nodetool -h localhost -p 7199 snapshot $mykeyspaces > snapshot_dir_list

## Create Snapshot archive
echo "Create Snapshot archive for $mykeyspaces"

X=$(cat snapshot_dir_list | grep "Snapshot directory:" | awk '{print $3}')
sudo find $dir -type d -name $X -execdir zip -r '{}'.gz '{}' \;

## Encrypte archive and send to Bucket
gzfile=$(sudo find $dir -type f -name $X.gz)

	for gpgfile in $gzfile; do
	sudo gpg --no-verbose -e -r ServerAdmin $gpgfile ## Encrypt Snapshot
	/usr/local/bin/aws s3 cp --quiet $gpgfile s3://$bucket/$servername/$date$gpgfile.gpg ## Send Snapshot to Bucket
	if [ "$?" -ne "0" ]; then
	echo "Upload to AWS failed" 
	else
	echo "Upload to AWS has been completed with successful" 
	fi
		## Sync Backufor mykeyspaces in $KEY; dop with Storage Folder
		if [ $day = 1 ]; then
		/usr/local/bin/aws s3 sync --quiet s3://$bucket/$servername/$date s3://$bucket/backupstorage/$servername/$date/
		fi
	done

done

## clean up files
nodetool -h localhost -p 7199 clearsnapshot
rm snapshot_dir_list
