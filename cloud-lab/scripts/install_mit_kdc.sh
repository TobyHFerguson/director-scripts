#!/bin/bash
trap exit ERR
yum -y install krb5-server rng-tools

function svcctl() {
    if which systemctl 2>/dev/null
    then
       systemctl $@
    else
	if [ "$1" = "enable" ]
	then
	    chkconfig $2 on
	else
	    service $2 $1
	fi
    fi
}

grep rdrand /proc/cpuinfo || echo 'EXTRAOPTIONS="-r /dev/urandom"' >> /etc/sysconfig/rngd
svcctl start rngd

REALM=HADOOPSECURITY.LOCAL

PRIVATE_IP=$(hostname -I)

cp -f /etc/krb5.conf{,.original}

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
  kdc = ${PRIVATE_IP:?}
  admin_server = ${PRIVATE_IP:?}
 }
EOF

mv /var/kerberos/krb5kdc/kadm5.acl{,.original}
cat - >/var/kerberos/krb5kdc/kadm5.acl <<EOF
*/admin@${REALM:?}	*
EOF

mv /var/kerberos/krb5kdc/kdc.conf{,.original}
cat - >/var/kerberos/krb5kdc/kdc.conf <<EOF
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 ${REALM:?} = {
 acl_file = /var/kerberos/krb5kdc/kadm5.acl
 dict_file = /usr/share/dict/words
 admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
 supported_enctypes = aes256-cts-hmac-sha1-96:normal aes128-cts-hmac-sha1-96:normal arcfour-hmac-md5:normal
 max_renewable_life = 7d
}
EOF


kdb5_util create -P Passw0rd!

svcctl start krb5kdc
svcctl enable krb5kdc
svcctl start kadmin
svcctl enable kadmin
svcctl stop iptables || :

# use this technique instead of kadmin.local addprinc -pw ... because
# the version of kadmin.local on CentOS6 doesn't allow for passing
# commands in directly.

echo -e 'addprinc -pw Passw0rd! cm/admin\nexit' | kadmin.local 
echo -e 'addprinc -pw Cloudera1 cdsw\nexit' | kadmin.local 

# Ensure that selinux is turned off now and at reboot
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

