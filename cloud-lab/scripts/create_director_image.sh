#!/bin/bash
# $1 - AWS_ACCESS_KEY_ID
# $2 - AWS_SECRET_ACCESS_KEY
# $3 - Owner - optional; defaults to user running script
# $4 - base directory for cloud lab - optional

[[ 2 -le $# && $# -le 4 ]] || {
    cat - 1>&2 <<EOF
$0: ERROR: Expected between 2 and 4 arguments, got $#
Usage: $0 AWS_ACCESS_KEY_ID AWS_SECRET_KEY_ID [Owner - defaults to value of USER env] [base_dir - defaults to /tmp/cloud_lab]
EOF
    exit 2
}

export AWS_ACCESS_KEY_ID=${1:?}
export AWS_SECRET_ACCESS_KEY=${2:?}
OWNER=${3:-${USER:?}}
CLOUD_LAB_DIR=${4:-/tmp/cloud_lab}


export AWS_DEFAULT_REGION=us-east-1

# CONSTANTS

#CLUSTER_CDH_AMI=ami-49e9fe5e	# AMI for pre-created CDH image
#CLUSTER_CDH_AMI=ami-05a75613	# AMI for pre-created CDH image - 5.9
CLUSTER_CDH_AMI=ami-6e6aab78	# CDH 5.10 CentOS 72
CLUSTER_OS_USER=centos		# User to ssh to CDH image
#DIRECTOR_OS_AMI=ami-0ca23e1b	# AMI to use for Director - RHEL 73
#DIRECTOR_OS_AMI=ami-f9bb55ef    # prebuilt ami
DIRECTOR_OS_AMI=ami-ea6cadfc	 # Director 2.3.0/RHEL 73 AMI
DIRECTOR_OS_USER=ec2-user	# User to ssh to Director
DIRECTOR_INSTANCE_TYPE=c4.xlarge # Director instance type
INSTANCENAME=${OWNER:?}-director	 # Name for Director instance
SECURITY_GROUP=sg-891a50f1	 # Security group controlling the cluster
SUBNET_ID=subnet-e7542291	 # Subnet within which the cluster will run

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

# Construct the output directory structures and file names
BASE_DIR=${CLOUD_LAB_DIR:?}/${OWNER:?}.$$/ # base for this specific session with this specific owner
OUTPUT_DIR=${BASE_DIR:?}/output		   # output directory used to create zip file
STAGE_DIR=${BASE_DIR:?}/stage		   # stage directory used to expand template files
TMP_DIR=${BASE_DIR:?}/tmp		   # tmp directory for scripts and other calculated items
mkdir -p ${OUTPUT_DIR:?}
mkdir -p ${STAGE_DIR:?}
mkdir -p ${TMP_DIR:?}

# temp directory
SSH_PRIVATE_KEY=${TMP_DIR:?}/private_key # the private key made into an easily substituted string
SED_COMMANDS_FILE=${TMP_DIR:?}/commands.sed # a file containing the template expansion commands

# Output directory
SSH_CONFIG_FILE=${OUTPUT_DIR:?}/ssh_config # The config file for owner to use
README=${OUTPUT_DIR:?}/README		   # The README for the user

# # construct a brand new key pair and put the private key into a file
AWS_KEYNAME=$(make-key-name)
AWS_SSH_KEYFILE=${OUTPUT_DIR:?}/${AWS_KEYNAME:?}
touch ${AWS_SSH_KEYFILE:?}
chmod 600 ${AWS_SSH_KEYFILE:?}
aws ec2 create-key-pair --output text --key-name ${AWS_KEYNAME:?} --query 'KeyMaterial' >${AWS_SSH_KEYFILE:?} || {
    err "Failed to create a keypair. Cleaning up and exiting"
    aws ec2 delete-key-pair --key-name ${AWS_KEYNAME:?}
    rm -f ${AWS_KEYNAME:?}
    exit 2
    }

# Get the various resources from the cloud provider
INSTANCE_ID=$(aws ec2 run-instances --image-id ${DIRECTOR_OS_AMI:?} --count 1 --instance-type ${DIRECTOR_INSTANCE_TYPE:?} --key-name ${AWS_KEYNAME:?} --security-group-ids ${SECURITY_GROUP:?} --subnet-id ${SUBNET_ID:?} --disable-api-termination --output text | grep INSTANCES | cut -f 8)

until aws ec2 create-tags --resources ${INSTANCE_ID:?} --tags Key=owner,Value=${OWNER:?} Key=Name,Value=${INSTANCENAME:?} 2>/dev/null; do sleep 1; done

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

# Create as much as possible on local disk before operating on the remote instance

# Create the temp directory files
## The private key
sed -e 's|\(-----BEGIN RSA PRIVATE KEY-----\)|    privateKey: """\1|' -e 's|\(-----END RSA PRIVATE KEY-----\)|\1"""|' ${AWS_SSH_KEYFILE:?} >${SSH_PRIVATE_KEY:?}

## the sed command file
cat - > ${SED_COMMANDS_FILE:?} <<EOF
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


# Create the output directory files
# The ssh config file
cat - >${SSH_CONFIG_FILE:?} <<EOF
Host director
     Hostname ${DIRECTOR_IP_ADDRESS:?}
     User ${DIRECTOR_OS_USER:?}
     IdentityFile ${AWS_SSH_KEYFILE:?}
     CheckHostIP no
     StrictHostKeyChecking no
EOF


## The README
cat - >${README:?} <<EOF
ssh
   ssh configuration to access your director instance is in ssh_config
   The private keyfile for your director instance is in ${AWS_KEYNAME:?}

Creating an Analytic Cluster
   Create an analytic cluster by executing the following (in this directory):

   ssh -qtF ssh_config director 'cloudera-director bootstrap-remote analytic_cluster.conf --lp.remote.username=admin --lp.remote.password=admin'

Making the output table
   Locate the Cloudera Manager URL by executing:

   ssh -qtF ssh_config director ./get_cm_url.sh

   In a browser access Hue via Cloudera Manager and create the etl output table by executing the following sql in the Impala Query Editor: 

   CREATE EXTERNAL TABLE etl_table (d_year string,brand_id int,brand string,sum_agg float)  LOCATION 's3a://${BUCKET_NAME:?}/output'

Executing the ETL Job
   Execute the ETL job to fill the output table by executing the following:
   
   ssh -qtF ssh_config director './run_all.sh' 

EOF


# Expand the templates

# Substitute for the variables into the staging files
for file in ../templates/*
do
    sed -f ${SED_COMMANDS_FILE:?} $file >${STAGE_DIR:?}/$(basename $file)
done
# Make the shell scripts executable
chmod a+x ${STAGE_DIR:?}/*.sh

# Copy files to the director instance
## Wait until we have ssh access
message "Waiting for ssh access to instance id: ${INSTANCE_ID:?}"
until ssh -q  -F ${SSH_CONFIG_FILE:?} director 'echo hi >/dev/null'; do message "Waiting for ssh access to instance id: ${INSTANCE_ID:?}"; sleep 10; done


message "Copying files to the director instance"
## copy over the keyfile
scp -qF ${SSH_CONFIG_FILE:?} ${AWS_SSH_KEYFILE:?} director:.ssh/id_rsa

## Make the aws directory on the director
ssh -qtF ${SSH_CONFIG_FILE:?} director 'mkdir -p ~/.aws'

## Copy the expanded credential and config file over and then delete them from the staging directory
scp -F ${SSH_CONFIG_FILE} ${STAGE_DIR:?}/{config,credentials} director:.aws/ &&
rm -f ${STAGE_DIR:?}/{config,credentials}

## Copy over the remaining files from the staging directory into the director's home directory.
scp  -F ${SSH_CONFIG_FILE:?} ${STAGE_DIR:?}/* install_director.sh director:


# All done - make the zip file from the output directory and put it somewhere for temporary safe keeping
## Edit the IdentityFile location to make it local to the ${OUTPUT_DIR:?}
sed -i '' s@${OUTPUT_DIR:?}/@@ ${SSH_CONFIG_FILE:?}
ZIPFILE=/tmp/${OWNER:?}.$$.zip
rm -f ${ZIPFILE:?}
zip -j ${ZIPFILE:?} ${OUTPUT_DIR:?}/*

message "Created zip file ${ZIPFILE:?} containing instructions for ${OWNER:?}"
