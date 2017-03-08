### TESTED ON RHEL 7.3
#### Install Director
sudo yum -y update
sudo yum install -y wget unzip
JDK_URL=http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/jdk-8u121-linux-x64.rpm
wget --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' ${JDK_URL:?}
sudo yum -y localinstall jdk*.rpm && rm -f jdk*.rpm
cd /etc/yum.repos.d/
sudo wget "http://archive.cloudera.com/director/redhat/7/x86_64/director/cloudera-director.repo"
sudo yum install -y cloudera-director-server cloudera-director-client
sudo service cloudera-director-server start
cd ~
#### INSTALL JQ
wget http://stedolan.github.io/jq/download/linux64/jq
chmod +x ./jq
sudo mv jq /usr/bin
#### SET PERMISSIONS TO SSH KEY
chmod 600 ~/.ssh/id_rsa
#### INSTALL AWS CLI (OPTIONAL TO COPY LOGS LATER)
curl -O "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws && rm -rf awscli-bundle*
### Setup for reboot
sudo systemctl enable cloudera-director-server
sudo systemctl start cloudera-director-server
if systemctl list-units | grep -q firewalld
then
    sudo systemctl disable firewalld
    sudo systemctl stop firewalld
fi
