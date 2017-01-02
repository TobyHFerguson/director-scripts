# TESTED ON RHEL 7.2 and Centos 7.2
## Install basics
sudo yum -y update
sudo yum install -y wget unzip

## Install & Configure MariaDB
sudo yum -y install mariadb-server

### Configure MariaDB to use the innodb storage system
cat - >/tmp/my.cnf << EOF
[mysqld]
default-storage-engine = innodb
transaction-isolation = READ-COMMITTED
# Disabling symbolic-links is recommended to prevent assorted security risks;
# to do so, uncomment this line:
symbolic-links = 0

key_buffer = 16M
key_buffer_size = 32M
max_allowed_packet = 32M
thread_stack = 256K
thread_cache_size = 64
query_cache_limit = 8M
query_cache_size = 64M
query_cache_type = 1

max_connections = 550

#log_bin should be on a disk with enough free space. Replace '/var/lib/mysql/mysql_binary_log' with an appropriate path for your system.
#log_bin=/var/lib/mysql/mysql_binary_log
#expire_logs_days = 10
#max_binlog_size = 100M

# For MySQL version 5.1.8 or later. Comment out binlog_format for older versions.
binlog_format = mixed

read_buffer_size = 2M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M

# InnoDB settings
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit  = 2
innodb_log_buffer_size = 64M
innodb_buffer_pool_size = 4G
innodb_thread_concurrency = 8
innodb_flush_method = O_DIRECT
innodb_log_file_size = 512M

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF
sudo mkdir -p /etc/mysql
sudo mv -f /tmp/my.cnf /etc/mysql
sudo chown root:root /etc/mysql/my.cnf
sudo chmod 644 /etc/mysql/my.cnf

### Ensure mariadb starts on reboot and is started now
sudo systemctl enable mariadb
sudo systemctl start mariadb

### Secure the instance, and add tables etc. for the 'director' user:
cat - >/tmp/mdb.sql <<EOF
create database director DEFAULT CHARACTER SET utf8;
grant all on director.* TO 'director'@'%' IDENTIFIED BY 'password';

set password = password('password');
grant all on *.* to 'root'@'%' identified by 'password' with grant option;
EOF
mysql -u root --password=password </tmp/mdb.sql

### Install the jdbc drivers
cd /tmp
curl -L -O http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.40.tar.gz &&
tar zxvf mysql-connector-java-5.1.40.tar.gz &&
sudo mkdir -p /usr/share/java &&
sudo cp mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar /usr/share/java/mysql-connector-java.jar &&
sudo chmod -R a+r /usr/share/java &&
rm -R mysql-connector-java-5.1.40 mysql-connector-java-5.1.40.tar.gz

## Install Director
wget --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' http://download.oracle.com/otn-pub/java/jdk/8u102-b14/jdk-8u102-linux-x64.rpm
sudo yum -y localinstall jdk-8u102-linux-x64.rpm
cd /etc/yum.repos.d/
sudo wget "http://archive.cloudera.com/director/redhat/7/x86_64/director/cloudera-director.repo"
sudo yum install -y cloudera-director-server cloudera-director-client

### Configure director to use mariadb by uncommenting this one line
sudo sed -i '/lp.database.type/s/^#//' /etc/cloudera-director-server/application.properties

### Ensure that director starts after mariadb on reboot
sed -i '/\[Unit\]/aAfter=mariadb.service' /run/systemd/generator.late/cloudera-director-server.service

### Ensure director starts at reboot, and is started now:
sudo systemctl enable cloudera-director-server
sudo systemctl start cloudera-director-server

## Install ancilliary programs
cd ~
### INSTALL JQ
wget http://stedolan.github.io/jq/download/linux64/jq
chmod +x ./jq
sudo cp jq /usr/bin
### SET PERMISSIONS TO SSH KEY
chmod 600 ~/.ssh/id_rsa
### INSTALL PACKER
wget https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip
unzip packer_0.10.1_linux_amd64.zip
sudo mv packer /usr/local/bin/
### INSTALL AWS CLI (OPTIONAL TO COPY LOGS LATER)
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
