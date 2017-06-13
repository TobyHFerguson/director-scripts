### TESTED ON RHEL 7.2
#### Install Director
trap exit ERR
sudo yum -y update
sudo yum install -y wget unzip
JDK_URL=http://download.oracle.com/otn-pub/java/jdk/8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/jre-8u131-linux-x64.rpm
wget --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' ${JDK_URL:?}
sudo yum -y localinstall jre*.rpm && rm -f jre*.rpm
cd /etc/yum.repos.d/
sudo wget "http://archive.cloudera.com/director/redhat/7/x86_64/director/cloudera-director.repo"
sudo yum install -y cloudera-director-server cloudera-director-client

### Setup for reboot
sudo systemctl enable cloudera-director-server
sudo systemctl start cloudera-director-server
if systemctl list-units | grep -q firewalld
then
    sudo systemctl disable firewalld
    sudo systemctl stop firewalld
fi



