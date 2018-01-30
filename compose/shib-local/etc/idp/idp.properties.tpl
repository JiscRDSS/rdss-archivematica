
# Required params
idp.scope=${IDP_DOMAIN}
idp.entityID=https://${IDP_HOSTNAME}/idp/shibboleth
idp.ldap.basedn=${IDP_DOMAIN_BASEDN}
idp.ldap.host=${IDP_LDAP_HOSTNAME}

# Security
idp.signing.key = /etc/pki/shibboleth-idp/idp-signing.key
idp.signing.cert = /etc/pki/shibboleth-idp/idp-signing.crt
idp.encryption.key = /etc/pki/shibboleth-idp/idp-encryption.key
idp.encryption.cert = /etc/pki/shibboleth-idp/idp-encryption.crt
idp.sealer.keyPassword = ${IDP_KEYSTORE_PASSWORD}
idp.sealer.storePassword = ${IDP_KEYSTORE_PASSWORD}

# Relax requirement for authn request to be encrypted (for testing only)
idp.encryption.optional = true

# Enable detailed error messages sent back to SP
idp.errors.detailed = true

# Enable Single Log Out (SLO)
idp.logout.authenticated = true
idp.logout.elaboration = true
idp.session.enabled = true
idp.session.secondaryServiceIndex = true
idp.session.trackSPSessions = true
idp.storage.htmlLocalStorage = true
