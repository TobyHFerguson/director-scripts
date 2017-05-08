#!/bin/bash
yum -y install krb5-workstation openssl-clients unzip

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

# curl -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip | unzip

# mv UnlimitedJCEPolicy/*.jar /usre/java/jdk1.
