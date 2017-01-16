#!/bin/bash
# $1 - AWS_ACCESS_KEY_ID
# $2 - AWS_SECRET_ACCESS_KEY
export AWS_ACCESS_KEY_ID=${1:?}
export AWS_SECRET_ACCESS_KEY=${2:?}
OWNER=${3:?}

export AWS_DEFAULT_REGION=us-east-1

# CONSTANTS
CLUSTER_CDH_AMI=ami-49e9fe5e	# AMI for pre-created CDH image
CLUSTER_OS_USER=centos		# User to ssh to CDH image
DIRECTOR_OS_AMI=ami-0ca23e1b	# AMI to use for Director - RHEL 73
DIRECTOR_OS_AMI=ami-5ca14f4a # prebuilt ami
DIRECTOR_OS_USER=ec2-user	# User to ssh to Director
DIRECTOR_INSTANCE_TYPE=c4.xlarge # Director instance type
INSTANCENAME=${OWNER:?}-director	 # Name for Director instance
SECURITY_GROUP=sg-891a50f1	 # Security group controlling the cluster
SUBNET_ID=subnet-e7542291	 # Subnet within which the cluster will run

# Create a directory to put the ssh information in
SSH_DIR=/tmp/cloud-lab-${OWNER:?}
rm -rf ${SSH_DIR:?}
mkdir -p ${SSH_DIR:?}

function random() {
    SEED="$(date) $RANDOM"
    case $(uname -s) in
	"Darwin") echo $SEED | md5;;
	"Linux") echo $SEED | md5sum | cut -d' ' -f1
    esac
}

function message() {
    cat - <<EOF
$0: $1 
EOF
}

function make-bucket-name() {
    echo cloud-lab-${OWNER:?}-bucket-$(random)
}

function make-key-name() {
    echo cloud-lab-${OWNER:?}-keypair-$(random)
}

function create-uniq-bucket() {
    bn=$(make-bucket-name)
    while aws s3 ls s3://$bn 2>/dev/null 1>&2
    do
	bn=$(make-bucket-name)
    done
    aws s3 mb s3://$bn 2>/dev/null 1>&2
    echo $bn
}


# # construct a brand new key pair and put the private key into a file
AWS_KEYNAME=$(make-key-name)
AWS_SSH_KEYFILE=${SSH_DIR:?}/${AWS_KEYNAME:?}
touch ${AWS_SSH_KEYFILE:?}
chmod 600 ${AWS_SSH_KEYFILE:?}
aws ec2 create-key-pair --output text --key-name ${AWS_KEYNAME:?} --query 'KeyMaterial' >${AWS_SSH_KEYFILE:?} || {
    err "Failed to create a keypair. Cleaning up and exiting"
    aws ec2 delete-key-pair --key-name ${AWS_KEYNAME:?}
    rm -f ${AWS_KEYNAME:?}
    exit 2
    }

INSTANCE_ID=$(aws ec2 run-instances --image-id ${DIRECTOR_OS_AMI:?} --count 1 --instance-type ${DIRECTOR_INSTANCE_TYPE:?} --key-name ${AWS_KEYNAME:?} --security-group-ids ${SECURITY_GROUP:?} --subnet-id ${SUBNET_ID:?} --disable-api-termination --output text | grep INSTANCES | cut -f 8)
aws ec2 create-tags --resources ${INSTANCE_ID:?} --tags Key=owner,Value=${OWNER:?} Key=Name,Value=${INSTANCENAME:?}
message "Created instance named ${INSTANCENAME:?}, id: ${INSTANCE_ID:?} tagged with owner = ${OWNER:?}. 
	Waiting up to 40 seconds for instance to become available"

aws ec2 wait instance-running --instance-ids ${INSTANCE_ID:?} || {
    echo "The instance ${INSTANCE_ID:?} is not running after 40 seconds. Aborting" 1>&2
    exit 2
    }

message "Instance ${INSTANCE_ID:?} available - proceeding"

DIRECTOR_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output text | grep ASSOCIATION | head -1 | cut -f3)
DIRECTOR_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output text | grep PRIVATEIPADDRESSES | cut -f4)
SUBNET_ID=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output text | grep ^INSTANCES | cut -f20)
SECURITY_GROUP_ID=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output text | grep ^SECURITYGROUPS | cut -f2)

BUCKET_NAME=$(create-uniq-bucket)
message "created bucket s3://${BUCKET_NAME:?}/"


# anything could be in here
SSH_PRIVATE_KEY=/tmp/pk.$$
sed -e 's|\(-----BEGIN RSA PRIVATE KEY-----\)|    privateKey: """\1|' -e 's|\(-----END RSA PRIVATE KEY-----\)|\1"""|' ${AWS_SSH_KEYFILE:?} >${SSH_PRIVATE_KEY:?}


cat - >/tmp/commands.sed <<EOF
s|REPLACE_ME_AWS_ACCESS_KEY_ID|${AWS_ACCESS_KEY_ID:?}|g
s|REPLACE_ME_AWS_SECRET_ACCESS_KEY|${AWS_SECRET_ACCESS_KEY:?}|g
s|REPLACE_ME_BUCKET_NAME|${BUCKET_NAME:?}|g
s|REPLACE_ME_CLUSTER_CDH_AMI|${CLUSTER_CDH_AMI:?}|g
s|REPLACE_ME_CLUSTER_OS_USER|${CLUSTER_OS_USER:?}|g
s|REPLACE_ME_DIRECTOR_PRIVATE_IP|${DIRECTOR_PRIVATE_IP:?}|g
s|REPLACE_ME_OWNER|${OWNER:?}|g
s|REPLACE_ME_REGION|${AWS_DEFAULT_REGION:?}|g
s|REPLACE_ME_SECURITY_GROUP_ID|${SECURITY_GROUP_ID:?}|g
/REPLACE_ME_SSH_PRIVATE_KEY/{
r ${SSH_PRIVATE_KEY:?}
d
}
s|REPLACE_ME_SUBNET_ID|${SUBNET_ID:?}|g
EOF


STAGE_DIR=/tmp/create_director.$$
mkdir /tmp/create_director.$$


SSH_CONFIG_FILE=${SSH_DIR:?}/ssh_config
cat - >${SSH_CONFIG_FILE:?} <<EOF
Host director
     Hostname ${DIRECTOR_IP_ADDRESS:?}
     User ${DIRECTOR_OS_USER:?}
     IdentityFile ${AWS_SSH_KEYFILE:?}
     CheckHostIP no
     StrictHostKeyChecking no
EOF

# Substitute for the variables into the staging files
for file in hive-example/*
do
    sed -f /tmp/commands.sed $file >${STAGE_DIR:?}/$(basename $file)
done
# Make the shell scripts executable
chmod a+x ${STAGE_DIR:?}/*.sh

# Wait until we have ssh access
message "Waiting for ssh access to instance id: ${INSTANCE_ID:?}"
until ssh -q  -F ${SSH_CONFIG_FILE:?} director 'echo hi >/dev/null'; do message "Waiting for ssh access to instance id: ${INSTANCE_ID:?}"; sleep 10; done

message "Copying files to the director instance"
# copy over the keyfile
scp -qF ${SSH_CONFIG_FILE:?} ${AWS_SSH_KEYFILE:?} director:.ssh/id_rsa

# Make the aws directory on the director
ssh -qtF ${SSH_CONFIG_FILE:?} director 'mkdir -p ~/.aws'

# Copy the expanded credential and config file over and then delete them from the staging directory
for file in ${STAGE_DIR:?}/{config,credentials}; do scp -F ${SSH_CONFIG_FILE} $file director:.aws/; rm -f $file; done

# Copy over the remaining files from the staging directory into the director's home directory.
for file in ${STAGE_DIR:?}/* install_director.sh ; do scp  -F ${SSH_CONFIG_FILE:?} $file director:; done

# Publish the text file

cat - >${SSH_DIR:?}/README <<EOF
ssh
   ssh configuration to access your director instance is in ssh_config
   The private keyfile for your director instance is in ${AWS_KEYNAME:?}

Creating an Analytic Cluster
   Create an analytic cluster by executing the following (in this directory):

   ssh -qtF ssh_config director 'cloudera-director bootstrap-remote analytic_cluster.conf --lp.remote.username=admin --lp.remote.password=admin'

Making the output table
   Create an output table by accessing HUE at http://${DIRECTOR_IP_ADDRESS:?}:8888, and enter the following command to make the output table:
   CREATE EXTERNAL TABLE etl_table (d_year string,brand_id int,brand string,sum_agg float)  LOCATION 's3a://${BUCKET_NAME:?}/output'

Executing the ETL Job
   Execute the ETL job to fill the output table by executing the following
   
   ssh -qtF ${SSH_CONFIG_FILE:?} director './run_all.sh\' 

EOF

# Edit the IdentityFile location to make it local to the ${SSH_DIR:?}
sed -i '' s@${SSH_DIR:?}/@@ ${SSH_CONFIG_FILE:?}
ZIPFILE=/tmp/${OWNER:?}.zip
zip -j ${ZIPFILE:?} ${SSH_DIR:?}/*

message "Created zip file ${ZIPFILE:?} containing instructions for ${OWNER:?}"

# message "Created ssh config file in ${SSH_CONFIG_FILE:?}. 
# Execute 
# 	ssh -qtF ${SSH_CONFIG_FILE:?} director 'cloudera-director bootstrap-remote analytic_cluster.conf --lp.remote.username=admin --lp.remote.password=admin' 
# to create the analytic (permanent) cluster

# When that is complete access HUE at http://${DIRECTOR_IP_ADDRESS:?}:8888, and enter the following command to make the output table:
# 	CREATE EXTERNAL TABLE etl_table (d_year string,brand_id int,brand string,sum_agg float)  LOCATION 's3a://${BUCKET_NAME:?}/output'

# Execute 
# 	ssh -qtF ${SSH_CONFIG_FILE:?} director './run_all.sh\' 
# to run the transient cluster etl job"
