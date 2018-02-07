<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    clockSkew="180">
    <RequestMapper type="XML">
        <RequestMap authType="shibboleth" requireSession="true">
          <!-- Declare the host for the Archivematica Dashboard -->
          <Host applicationId="am-dash"
            name="${AM_DASHBOARD_HOST:-dashboard.archivematica.example.ac.uk}"
            scheme="http" port="80">
            <!-- Access to the Archivematica Dashboard requires preservation entitlement -->
            <AccessControl>
                <OR>
                    <Rule require="entitlement">preservation-admin</Rule>
                    <Rule require="entitlement">preservation-user</Rule>
                </OR>
            </AccessControl>
            <!-- Don't apply access control to api and media resources -->
            <Path name="api" authType="None" requireSession="false"/>
            <Path name="media" authType="None" requireSession="false"/>
          </Host>
          <!-- Declare the host for the Archivematica Storage Service -->
          <Host applicationId="am-ss"
            name="${AM_STORAGE_SERVICE_HOST:-ss.archivematica.example.ac.uk}"
            scheme="http" port="80">
            <!-- Access to the Archivematica Storage Service requires preservation entitlement -->
            <AccessControl>
                <OR>
                    <Rule require="entitlement">preservation-admin</Rule>
                    <Rule require="entitlement">preservation-user</Rule>
                </OR>
            </AccessControl>
            <!-- Don't apply access control to api and static resources -->
            <Path name="api" authType="None" requireSession="false"/>
            <Path name="static" authType="None" requireSession="false"/>
          </Host>
        </RequestMap>
    </RequestMapper>
    <ApplicationDefaults entityID="default-always-overridden"
            REMOTE_USER="eppn persistent-id targeted-id"
            sessionHook="/Shibboleth.sso/AttrChecker"
            metadataAttributePrefix="Meta-" >
        <!-- Session config -->
        <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
                  checkAddress="false"
                  handlerSSL="false"
                  cookieProps="http">
            <SSO entityID="${SHIBBOLETH_IDP_ENTITY_ID:-https://idp.example.ac.uk/idp/shibboleth}">SAML2</SSO>
            <Logout>SAML2 Local</Logout>
            <Handler type="MetadataGenerator" Location="/metadata" signing="false"/>
            <Handler type="Status" Location="/status" />
            <Handler type="Session" Location="/session" showAttributeValues="true"/>
           <!-- Troubleshooting -->
           <Handler type="AttributeChecker" Location="/AttrChecker" attributes="cn entitlement eppn givenName mail sn"
                template="attrChecker.html" flushSession="true" showAttributeValues="true"/>
        </Sessions>
        <!-- Default trust credentials for TLS - use Dashboard key and certs -->
		<CredentialResolver type="File" use="TLS">
		  <Key>
			<Path>${AM_DASHBOARD_SSL_KEY_FILE:-/secrets/nginx/am-dash-key.pem}</Path>
		  </Key>
		  <Certificate>
			<Path>${AM_DASHBOARD_SSL_CERT_FILE:-/secrets/nginx/am-dash-cert.pem}</Path>
			<Path>${AM_DASHBOARD_SSL_CA_BUNDLE_FILE:-/secrets/nginx/sp-ca-bundle.pem}</Path>
		  </Certificate>
		</CredentialResolver>
        <!-- Metadata provider -->
        <MetadataProvider type="Dynamic"
            minCacheDuration="10" refreshDelayFactory="0.1">
                <Subst>${SHIBBOLETH_METADATA_URL_SUBST:-http://mdq.ukfederation.org.uk/entities/$entityID}</Subst>
                <MetadataFilter type="RequireValidUntil" maxValidityInterval="2592000"/>
                <MetadataFilter type="Signature" certificate="${SHIBBOLETH_METADATA_SIGNING_CERT:-ukfederation-mdq.pem}"/>
                <TrustEngine type="Chaining">
                <TrustEngine type="ExplicitKey"/>
                <TrustEngine type="StaticPKIX">
                    <!-- Use Dashboard key and cert when fetching IdP metadata -->
                    <CredentialResolver type="File" use="TLS">
                         <Key>
                             <Path>${AM_DASHBOARD_SSL_KEY_FILE:-/secrets/nginx/am-dash-key.pem}</Path>
                         </Key>
                         <Certificate>
                             <Path>${AM_DASHBOARD_SSL_CERT_FILE:-/secrets/nginx/am-dash-cert.pem}</Path>
                             <Path>${AM_DASHBOARD_SSL_CA_BUNDLE_FILE:-/secrets/nginx/sp-ca-bundle.pem}</Path>
                        </Certificate>
                    </CredentialResolver>
                </TrustEngine>
                <TrustEngine type="PKIX"/>
            </TrustEngine>
        </MetadataProvider>
        <!-- Attributes config -->
        <AttributeExtractor type="XML" validate="true" reloadChanges="true" path="attribute-map.xml"/>
        <AttributeResolver type="Query" subjectMatch="true"/>
        <AttributeFilter type="XML" validate="true" reloadChanges="true" path="attribute-policy.xml"/>
        <!-- Archivematica Dashboard application -->
        <ApplicationOverride id="am-dash"
          entityID="http://${AM_DASHBOARD_HOST:-dashboard.archivematica.example.ac.uk}/Shibboleth.sso/metadata">
            <!-- Trust credentials config -->
            <CredentialResolver type="File">
              <Key>
                <Path>${AM_DASHBOARD_SSL_KEY_FILE:-/secrets/nginx/am-dash-key.pem}</Path>
              </Key>
              <Certificate>
                <Path>${AM_DASHBOARD_SSL_CERT_FILE:-/secrets/nginx/am-dash-cert.pem}</Path>
                <Path>${AM_DASHBOARD_SSL_CA_BUNDLE_FILE:-/secrets/nginx/sp-ca-bundle.pem}</Path>
              </Certificate>
            </CredentialResolver>
            <!-- Trust engine -->
            <TrustEngine type="Chaining">
                <TrustEngine type="ExplicitKey"/>
                    <TrustEngine type="StaticPKIX">
                        <CredentialResolver type="File" use="TLS">
                             <Key>
                                 <Path>${AM_DASHBOARD_SSL_KEY_FILE:-/secrets/nginx/am-dash-key.pem}</Path>
                             </Key>
                             <Certificate>
                                 <Path>${AM_DASHBOARD_SSL_CERT_FILE:-/secrets/nginx/am-dash-cert.pem}</Path>
                                 <Path>${AM_DASHBOARD_SSL_CA_BUNDLE_FILE:-/secrets/nginx/sp-ca-bundle.pem}</Path>
                            </Certificate>
                        </CredentialResolver>
                    </TrustEngine>
                <TrustEngine type="PKIX"/>
            </TrustEngine>
        </ApplicationOverride>
        <!-- Archivematica Storage Service application -->
        <ApplicationOverride id="am-ss"
          entityID="http://${AM_STORAGE_SERVICE_HOST:-ss.archivematica.example.ac.uk}/Shibboleth.sso/metadata">
            <!-- Trust credentials config -->
            <CredentialResolver type="File">
              <Key>
                <Path>${AM_STORAGE_SERVICE_SSL_KEY_FILE:-/secrets/nginx/am-ss-key.pem}</Path>
              </Key>
              <Certificate>
                <Path>${AM_STORAGE_SERVICE_SSL_CERT_FILE:-/secrets/nginx/am-ss-cert.pem}</Path>
                <Path>${AM_STORAGE_SERVICE_SSL_CA_BUNDLE_FILE:-/secrets/nginx/sp-ca-bundle.pem}</Path>
              </Certificate>
            </CredentialResolver>
            <!-- Trust engine -->
            <TrustEngine type="Chaining">
                <TrustEngine type="ExplicitKey"/>
                    <TrustEngine type="StaticPKIX">
                        <CredentialResolver type="File" use="TLS">
                             <Key>
                                 <Path>${AM_STORAGE_SERVICE_SSL_KEY_FILE:-/secrets/nginx/am-dash-key.pem}</Path>
                             </Key>
                             <Certificate>
                                 <Path>${AM_STORAGE_SERVICE_SSL_CERT_FILE:-/secrets/nginx/am-dash-cert.pem}</Path>
                                 <Path>${AM_STORAGE_SERVICE_SSL_CA_BUNDLE_FILE:-/secrets/nginx/sp-ca-bundle.pem}</Path>
                            </Certificate>
                        </CredentialResolver>
                    </TrustEngine>
                <TrustEngine type="PKIX"/>
            </TrustEngine>
        </ApplicationOverride>
        <!-- Troubleshooting: Extracts support information for IdP from its metadata. -->
        <AttributeExtractor type="Metadata" errorURL="errorURL" DisplayName="displayName"
            InformationURL="informationURL" PrivacyStatementURL="privacyStatementURL"
            OrganizationURL="organizationURL">
            <ContactPerson id="Support-Contact"  contactType="support" formatter="$EmailAddress" />
            <Logo id="Small-Logo" height="16" width="16" formatter="$_string"/>
        </AttributeExtractor>
    </ApplicationDefaults>
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>
</SPConfig>
