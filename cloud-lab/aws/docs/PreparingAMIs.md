# Preparing AMIs for cloud-lab
# CDH
Use the instructions in ~directory-scripts/faster-bootstrap~. In brief here's what I do:
```sh
cd directory-scripts/faster-bootstrap
bash build-ami.sh -p  us-east-1 centos72
```
This will build a minimal CDH 5.10 (as of Q1 2017) ami
# Director
I haven't packerized this yet. I simply build an image in EC2 and then convert to an ami.

I use the latest rhel version, along with the latest director. 

I increase the root disc to 15G, just to allow a bit of headroom.

The critical issue is to ensure that director will run properly on reboot:
```sh
curl --remote-name --junk-session-cookies --insecure --location --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u102-b14/jdk-8u102-linux-x64.rpm
sudo yum -y localinstall jdk*.rpm
(cd /etc/yum.repos.d
 sudo curl --remote-name --location http://archive.cloudera.com/director/redhat/7/x86_64/director/cloudera-director.repo
)
sudo yum -y install cloudera-director-server cloudera-director-client
sudo systemctl enable cloudera-director-server
sudo systemctl start cloudera-director-server
if systemctl list-units | grep -q firewalld
then
    sudo systemctl disable firewalld
    sudo systemctl stop firewalld
fi
```
