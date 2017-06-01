Certificate Authority
=======================

Trust is a major part of Shibboleth's authentication mechanism. Everything in Shibboleth is trusted - or can be.

To facilitate trust between parties (IdPs and SPs), Shibboleth uses [PKIX](https://en.wikipedia.org/wiki/X.509#PKIX_Working_Group). This means that private keys are used to secure SSL connections, and to sign and decrypt messages sent between parties, and public certificates (which contain public keys) are used to encrypt and verify those messages.

The Certificate Authority (CA) issues certificates, in accordance with the PKI infrastructure. If a certificate is issued by the same party that is using that certificate, is is "self-signed", meaning that the party using that certificate is asserting itself as an authority as to the "trustworthiness" of that party and their certificate. If the receiving party is willing to trust the "word" of the sending party (i.e. the receiver already has the sender's certificate in their trust store) then this is sufficient, otherwise some other guarantee is required. The PKI mechanism enables this by allowing third parties to issue certificates to the sending party, so that the receiving party can then determine that, if they trust the third-party issuer, then they can also trust the sending party too.

The CA included here issues certificates for all parties that require them in this environment, which includes the IdP and SPs. Normally in PKI certificates are issued by a "root CA", that is, one that is well-known and whose certificates are installed automatically on most systems. Because our local CA is not linked to these root CAs, we must take additional steps to install the local CA's certificate into the trust stores of all relevant hosts, so that they each can trust the CA and therefore each other. This is done as part of the container set up and build process.

This folder contains scripts and configuration files to use OpenSSL to operate a CA. This CA is used during the build process of each of the containers to sign certificate signing requests (CSRs) from the containers, thereby maintaining the chain of trust between the hosts and the CA.

Initial Setup
---------------

The [init script](ca/init.sh) initializes the Certificate Authority, creating the initial certificate and database etc. This script only needs to be run once - it doesn't need to be re-run each build.

This script can be used to manage multiple domains. The CA for each domain has its files in the `domains` folder, under a sub-folder for that domain (e.g. `example.ac.uk`).

To specify a different domain during initial set up, use the `DOMAIN_NAME` environment variable:

	DOMAIN_NAME=my.edu ./init.sh

Signing Certificates
---------------------

For the most part, the CA script that will get the most use is the [sign.sh](ca/sign.sh) script. This is what's used to issue certificates to nodes, based on the CSR that they submit. For example:

	./sign.sh "myhost.domain.tld" /tmp/myhost.csr"

The above would issue a certificate with the CN `myhost.domain.tld` based on the CSR `/tmp/myhost.csr`. The issued certificate is put into the `ca/certs` directory within the [ca](ca) folder, where it may then be copied from.

Shibboleth is very particular about the types of certificates it will accept and the attributes they must have. Certificates are used in three places within the Shibboleth infrastructure:

1. To secure SSL connections. This applies equally to the HTTPS connection used by browsers to present web pages to the end user's client (their browser), as well as the HTTPS "backchannel" that the IdP and SPs use to communicate and send SAML2 messages to each other.
1. To encrypt SAML2 messages sent between parties.
1. To sign and verify SAML2 messages sent between parties.

All of these require that the certificates conform to X.509v3 and are signed with keys whose signature is SHA-256.

The IdP additionally requires that two subject alternative names are added to the certificate: a DNS name with the IdP's hostname, and a URI, which is the URL of the endpoint where clients (SPs) can obtain the IdP's Shibboleth metadata from. This is used for the SAML2 infrastructure to aid discovery.

Destroying the CA
------------------

If you really want to destroy the CA then the [nuke.sh](ca/nuke.sh) script will do this but, as the name suggests, it's brutal and there's no going back. Everything will be wiped, including all certificates for each domain, internal databases, and all folders.

Environment Variables
----------------------

The following environment variables can be used to configure the Certificate Authority.

| Variable | Description |
|---|---|
| `DOMAIN_NAME` | Sets the domain name for the Certificate Authority and all certificates issued by it. Default value is `example.ac.uk`. |
| `DOMAIN_ORGANISATION` | Sets the organisation for the Certificate Authority and all certificates issued by it. Default value is "Example University". |

Example usage:

	DOMAIN_NAME=my.edu DOMAIN_ORGANISATION="My Academy"
