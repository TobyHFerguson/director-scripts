#!/bin/bash

if [ $# -ne 1 ]
then
    cat - <<EOF
No IP for the KDC provided.
If you want to use the local instance then pass in the IP like this:
AWS: install_mit_client.sh $(curl http://169.254.169.254/latest/meta-data/local-ipv4)
Google: install_mit_client.sh $(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google");;
EOF
    exit 1
fi
MIT_KDC=${1}

yum -y install krb5-workstation openldap-clients unzip

REALM=HADOOPSECURITY.LOCAL


mv -f /etc/krb5.conf{,.original}

cat - >/etc/krb5.conf <<EOF
[libdefaults]
 default_realm = ${REALM:?}
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5
 default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5
 permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 arcfour-hmac-md5

[realms]
 ${REALM:?} = {
  kdc = ${MIT_KDC:?}
  admin_server = ${MIT_KDC:?}
 }
EOF

# curl -O -j -k -L -H 'Cookie: oraclelicense=accept-securebackup-cookie' http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip
# sudo unzip -o -j -d /usr/java/jdk1.7.0_67-cloudera/jre/lib/security UnlimitedJCEPolicyJDK7.zip

# Ensure that selinux is turned off now and at reboot
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

