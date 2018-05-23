### TESTED ON RHEL 7.2 and Centos 7.2
#### Install Director
sudo yum -y update
sudo yum install -y wget unzip

sudo rpm -ivh "http://archive.cloudera.com/director/redhat/7/x86_64/director/2.6.0/RPMS/x86_64/oracle-j2sdk1.8-1.8.0+update121-1.x86_64.rpm"
echo "export JAVA_HOME="/usr/java/jdk1.8.0_121-cloudera"" >> ~/.bashrc
echo "export PATH=$PATH:$JAVA_HOME/bin" >> ~/.bashrc
source ~/.bashrc

cd /etc/yum.repos.d/
sudo wget "https://archive.cloudera.com/director/redhat/7/x86_64/director/cloudera-director.repo"
sudo yum install -y cloudera-director-server cloudera-director-client
sudo service cloudera-director-server start
cd ~
#### INSTALL JQ
wget http://stedolan.github.io/jq/download/linux64/jq
chmod +x ./jq
sudo cp jq /usr/bin
#### SET PERMISSIONS TO SSH KEY
chmod 600 ~/.ssh/id_rsa
#### INSTALL PACKER
wget https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip
unzip packer_0.10.1_linux_amd64.zip
sudo mv packer /usr/local/bin/
#### INSTALL AWS CLI (OPTIONAL TO COPY LOGS LATER)
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
