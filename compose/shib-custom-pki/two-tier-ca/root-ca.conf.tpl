RANDFILE         = /dev/urandom

#
# Root CA config
#

[ ca ]
default_ca = rootCA

[ rootCA ]
dir              = ${CA_DIR}
certs            = $dir/certs
new_certs_dir    = $dir/newcerts
crl_dir          = $dir/crl
database         = $dir/db/index.txt
crlnumber        = $dir/db/crlnumber
serial           = $dir/db/serial
private_key      = $dir/private/${CA_NAME}.key
certificate      = $dir/private/${CA_NAME}.crt
crl              = $dir/private/crl.pem
RANDFILE         = $dir/private/.rand
default_days     = 3650
default_crl_days = 730
default_md       = sha512
preserve         = no
policy           = rootCA_policy
unique_subject   = no
copy_extensions  = copy
x509_extensions  = v3_req

[ rootCA_policy ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ crl_ext ]
issuerAltName           = issuer:copy
authorityKeyIdentifier  = keyid:always

#
# Certificate Requests config
#

[ req ]
default_bits            = 1024
default_md              = sha512
default_keyfile         = privkey.pem
distinguished_name      = req_distinguished_name
x509_extensions         = v3_ca
req_extensions          = v3_req
string_mask             = nombstr

[ req_distinguished_name ]
countryName             = Country Name (2 letter code)
countryName_min         = 2
countryName_max         = 2
stateOrProvinceName     = State or Province Name (full name)
localityName            = Locality Name (eg, city)
0.organizationName      = Organization Name (eg, company)
organizationalUnitName  = Organizational Unit Name (eg, section)
commonName              = Common Name (eg, YOUR name)
commonName_max          = 64
emailAddress            = Email Address
emailAddress_max        = 64

[ v3_ca ]
basicConstraints        = critical,CA:TRUE
keyUsage                = critical,any
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
keyUsage                = digitalSignature,keyEncipherment,cRLSign,keyCertSign
extendedKeyUsage        = serverAuth

[ v3_req ]
basicConstraints        = critical,CA:TRUE,pathlen:0
keyUsage                = critical,any
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
keyUsage                = digitalSignature,keyEncipherment,cRLSign,keyCertSign
extendedKeyUsage        = serverAuth