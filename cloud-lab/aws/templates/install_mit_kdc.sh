#!/bin/bash
yum -y install krb5-server expect

REALM=HADOOPSECURITY.COM

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

'[realms]'
 ${REALM:?} = {
  kdc = $(hostname -f)
  admin_server = $(hostname -f)
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
EOF


sudo kdb5_util create -s

systemctl start krb5kdc
systemctl enable krb5kdc
systemctl start kadmin
systemctl enable kadmin

sudo kadmin.local
addprinc -pw Passw0rd! cm/admin
