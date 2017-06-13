trap exit ERR
#### INSTALL AWS CLI (OPTIONAL TO COPY LOGS LATER)
yum -y install unzip
curl -O "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && rm -rf awscli-bundle*
