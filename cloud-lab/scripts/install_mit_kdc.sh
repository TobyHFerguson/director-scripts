#!/bin/bash
trap exit ERR
# fixed argument to say whether this is Amazon, Microsoft or Google
cloud_provider=${1?:'No cloud provider - needs to be on of A - Amazon; M - Microsoft or G - Google'}
case $cloud_provider in
     A*) PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4);;
     M*) echo 'Microsoft not supported' 1>&2; exit;;
     G*) PRIVATE_IP=$(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google");;
     *) exit;;
esac

yum -y install krb5-server rng-tools

systemctl start rngd

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

systemctl start krb5kdc
systemctl enable krb5kdc
systemctl start kadmin
systemctl enable kadmin

kadmin.local addprinc -pw Passw0rd! cm/admin
kadmin.local addprinc -pw Cloudera1 cdsw

# Ensure that selinux is turned off now and at reboot
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

