<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    clockSkew="180">
    <RequestMapper type="XML">
        <RequestMap authType="shibboleth" requireSession="true">
          <!-- Declare the host for the Archivematica Dashboard on port 443 -->
          <Host applicationId="archivematica-dashboard"
            name="${NGINX_HOSTNAME:-archivematica.example.ac.uk}"
            scheme="https" port="443">
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
          <!-- Declare the host for the Archivematica Storage Service on port 8443 -->
          <Host applicationId="archivematica-storage-service"
            name="${NGINX_HOSTNAME:-archivematica.example.ac.uk}"
            scheme="https" port="8443">
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
    <ApplicationDefaults entityID="https://${NGINX_HOSTNAME:-archivematica.example.ac.uk}/Shibboleth.sso/metadata" 
            REMOTE_USER="eppn persistent-id targeted-id"
            sessionHook="/Shibboleth.sso/AttrChecker"
            metadataAttributePrefix="Meta-" >
        <!-- Session config -->
        <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
                  checkAddress="false"
                  handlerSSL="true"
                  cookieProps="https">
            <SSO entityID="${SHIBBOLETH_IDP_ENTITY_ID:-https://idp.example.ac.uk/idp/shibboleth}">SAML2</SSO>
            <Logout>SAML2 Local</Logout>
            <Handler type="MetadataGenerator" Location="/metadata" signing="false"/>
            <Handler type="Status" Location="/status" />
            <Handler type="Session" Location="/session" showAttributeValues="true"/>
           <!-- Troubleshooting -->
           <Handler type="AttributeChecker" Location="/AttrChecker" attributes="cn entitlement eppn givenName mail sn"
                template="attrChecker.html" flushSession="true" showAttributeValues="true"/>
        </Sessions>
        <!-- Metadata config -->
        <MetadataProvider type="XML"
            uri="${SHIBBOLETH_IDP_METADATA_URL:-https://idp.example.ac.uk:4443/idp/shibboleth}"
            backingFilePath="idp-metadata.xml"
            minRefreshDelay="10" maxRefreshDelay="5000" refreshDelayFactory="0.1"/>
        <!-- Attributes config -->
        <AttributeExtractor type="XML" validate="true" reloadChanges="true" path="attribute-map.xml"/>
        <AttributeResolver type="Query" subjectMatch="true"/>
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>
        <!-- Trust credentials config -->
        <CredentialResolver type="File" key="/etc/shibboleth/sp-key.pem">
          <Certificate>
            <Path>/etc/shibboleth/sp-cert.pem</Path>
            <Path>/etc/shibboleth/sp-ca-cert.pem</Path>
          </Certificate>
        </CredentialResolver>
        <!-- Archivematica applications -->
        <ApplicationOverride id="archivematica-dashboard"
          entityID="https://${NGINX_HOSTNAME:-archivematica.example.ac.uk}/Shibboleth.sso/metadata"/>
        <ApplicationOverride id="archivematica-storage-service"
          entityID="https://${NGINX_HOSTNAME:-archivematica.example.ac.uk}:8443/Shibboleth.sso/metadata"/>
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
