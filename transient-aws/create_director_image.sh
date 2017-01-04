#!/bin/bash
### EDIT THESE TO MATCH YOUR ENVIRONMENT
#### AWS_SSH_KEYFILE - absolute path to where you stored the AWS SSH keyfile
AWS_SSH_KEYFILE=$HOME/.ssh/toby-aws
#### AWS_KEYNAME - absolute path to the AWS name of the key
AWS_KEYNAME=toby-aws
#### INSTANCENAME - name that the director instance will be given
INSTANCENAME=tobys-director
### END OF EDITS


# CONSTANTS
DIRECTOR_OS_AMI=ami-0ca23e1b
DIRECTOR_OS_USER=ec2-user
DIRECTOR_INSTANCE_TYPE=c4.xlarge
SECURITY_GROUP=sg-891a50f1
SUBNET_ID=subnet-e7542291

CLUSTER_CDH_AMI=ami-49e9fe5e
CLUSTER_OS_USER=centos

OWNER=$USER

BUCKET_NAME="$USER-bucket"

function message() {
    echo $0: $1 1>&2
}


INSTANCE_ID=$(aws ec2 run-instances --image-id ${DIRECTOR_OS_AMI:?} --count 1 --instance-type ${DIRECTOR_INSTANCE_TYPE:?} --key-name ${AWS_KEYNAME:?} --security-group-ids ${SECURITY_GROUP:?} --subnet-id ${SUBNET_ID:?} --disable-api-termination | grep INSTANCES | cut -f 8)
aws ec2 create-tags --resources ${INSTANCE_ID:?} --tags Key=owner,Value=${USER} Key=Name,Value=${INSTANCENAME:?}
message "Instance ID: ${INSTANCE_ID:?} created, now booting"

DIRECTOR_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output text | grep ASSOCIATION | head -1 | cut -f3)
DIRECTOR_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output text | grep PRIVATEIPADDRESSES | cut -f4)
SUBNET_ID=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output=text | grep ^INSTANCES | cut -f20)
SECURITY_GROUP_ID=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID:?} --output=text | grep ^SECURITYGROUPS | cut -f2)

if !aws s3 ls s3://${BUCKET_NAME:?} 2>/dev/null 1>&2
then
    message "Creating bucket s3://${BUCKET_NAME:?}"
    aws s3 mb s3://${BUCKET_NAME:?}
fi

# Definition of what's in the keys here:  https://alestic.com/2009/11/ec2-credentials/
# alphanumeric
AWS_ACCESS_KEY_ID=$(sed -n -e '/aws_access_key_id/s/.*=[ ][ ]*\(.*\)/\1/p' ~/.aws/credentials)
# alphanumeric and + and /
AWS_SECRET_ACCESS_KEY=$(sed -n -e '/aws_secret_access_key/s/.*=[ ][ ]*\(.*\)/\1/p' ~/.aws/credentials)
# alphanumeric and -
REGION=$(sed -n -e '/region/s/.*=[ ][ ]*\(.*\)/\1/p' ~/.aws/config)


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
s|REPLACE_ME_REGION|${REGION:?}|g
s|REPLACE_ME_SECURITY_GROUP_ID|${SECURITY_GROUP_ID:?}|g
/REPLACE_ME_SSH_PRIVATE_KEY/{
r ${SSH_PRIVATE_KEY:?}
d
}
s|REPLACE_ME_SUBNET_ID|${SUBNET_ID:?}|g
EOF


STAGE_DIR=/tmp/create_director.$$
mkdir /tmp/create_director.$$

# Create an ssh config file
SSH_CONFIG_FILE=./config.$$
cat - >${SSH_CONFIG_FILE:?} <<EOF
Host director
     Hostname ${DIRECTOR_IP_ADDRESS:?}
     User ${DIRECTOR_OS_USER:?}
     IdentityFile ${AWS_SSH_KEYFILE:?}
     CheckHostIP no
     StrictHostKeyChecking no
EOF

message "Created ssh config file in ${SSH_CONFIG_FILE:?}. Execute \'ssh -F ${SSH_CONFIG_FILE:?} director\' to access the director instance"

# Substitute for the variables into the staging files
for file in hive-example/*
do
    sed -f /tmp/commands.sed $file >${STAGE_DIR:?}/$(basename $file)
done
# Make the shell scripts executable
chmod a+x ${STAGE_DIR:?}/*.sh

# Wait until we have ssh access
until ssh -q  -F ${SSH_CONFIG_FILE:?} director 'echo hi >/dev/null'; do message "Waiting for ssh access to instance id: ${INSTANCE_ID:?}"; sleep 10; done

# copy over the keyfile
scp -F ${SSH_CONFIG_FILE:?} ${AWS_SSH_KEYFILE:?} director:.ssh/id_rsa

# Copy over the aws directory for credentials etc.
scp  -F ${SSH_CONFIG_FILE:?} -r ~/.aws director:

# Copy over the necessary files for operation into the home directory.
for file in ${STAGE_DIR:?}/* install_director.sh ; do scp  -F ${SSH_CONFIG_FILE:?} $file director:; done

# Install director
ssh -t -F ${SSH_CONFIG_FILE:?} director 'bash ./install_director.sh'
