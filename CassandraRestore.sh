#!/bin/bash

FOLDER=$HOME/restore/
CASSANDRADATA=/var/lib/cassandra/data/
BUCKET=researchresearch-live-cassandra-backups
SERVER=ec2-11-11-111-123.eu-west-1.compute.amazonaws.com ### Cassandra Server
AWSPROFILE=Backups_Account
KEYSPACES=database

LATEST=$(aws s3 --profile $AWSPROFILE ls s3://$BUCKET/$SERVER/ | awk -F'PRE' '{ print $NF }' | tail -1 | tr -d '[:space:]')

function CHECK {
if [[ "$?" == "0" ]]
	then
        echo "OK...!!!"
	else
	echo "Error... Please investigate....!!!!"	
fi

}

sudo rm -r $FOLDER*
mkdir -p $FOLDER

echo "Download $KEYSPACES keyspace"
sudo aws s3 --profile $AWSPROFILE cp --recursive --quiet s3://$BUCKET/$SERVER/$LATEST $FOLDER
CHECK
for GPGFILE in $(find $FOLDER -name "*.gz.gpg"); do
	
	echo "Decrypt $KEYSPACES keyspace"
        echo "XXXXXXXXXXXXXXXX" | sudo gpg -q --passphrase-fd 0 --batch -d --output $(echo $GPGFILE | awk -F'.gpg' '{print $1}') --decrypt $GPGFILE &> /dev/null
	CHECK
	
	echo "Unzip $KEYSPACES keyspace"
        sudo unzip -q $(echo $GPGFILE | awk -F'.gpg' '{print $1}') -d $FOLDER
	CHECK
        sudo find $FOLDER -type f \( -name "*gpg" -o -name "*gz" \) -exec rm {} \; ## Be careful with this
done

cqlsh -e  "DROP KEYSPACE $KEYSPACES ;"
sudo rm -r $CASSANDRADATA$KEYSPACES/

echo "Import $KEYSPACES schema"
cqlsh -e "SOURCE '$FOLDER$KEYSPACES.cql'" 
CHECK

for TABLE in $(find $FOLDER$KEYSPACES/ -type d -not -path "*/backups" -not -path "*/snapshots"  -not -path "*/"); do
        echo "Restore $KEYSPACES tables" 
	echo $TABLE | awk -F'/' '{print $NF}'
	sudo sstableloader --no-progress -d 127.0.0.1 $TABLE &> /dev/null
	CHECK
done
