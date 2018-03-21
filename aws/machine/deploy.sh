#!/bin/bash

#
# Deploys an Arkivum appliance, NFS server and docker host into AWS,
# provisioning them if necessary, and ensures that all Archivematica-related
# containers are built and started. It also mounts the appliance and NFS server
# into the docker host and create docker external volumes for them.
# Also creates a public and private hosted zone and registers hosts and services
# with them as appropriate. The public zone is intended to be referenced by an
# existing domain, so this domain's nameserver information must be updated.
#
# Configuration is read from ./etc/deployment.conf, which must be created from
# the ./etc/deployment.conf.template template file. This configuration may be
# overriden using environment variables.
#
# Example usage:
#    S3_BUCKET_PARAMS="my-data-bucket:MY-ACCESS-KEY-ID:MY-SECRET_KEY:/mnt/s3/data" \
#        ./deploy.sh
#

# shellcheck disable=SC2034
PROGNAME="$(basename "${BASH_SOURCE[0]}" | cut -d. -f1)"
SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

# Include library modules
# shellcheck source=./lib/libs.sh
source "${SCRIPT_DIR}/lib/libs.sh"

# The AMI for the Arkivum 3 image.
ARKIVUM_3_AMI="ami-25140241"

# The AMI to use for the NFS server.
NFS_SERVER_AMI="ami-b6daced2"

# The Git repository to pull the RDSS-Archivematica source from
RDSS_ARCHIVEMATICA_REPO="https://github.com/JiscRDSS/rdss-archivematica.git"

# Do we have Shibboleth enabled?
SHIB_ENABLED="false"
if [ ! -z "${SHIBBOLETH_CONFIG}" ] && [ "${SHIBBOLETH_CONFIG}" != "none" ] ; then
    SHIB_ENABLED="true"
fi

# Deployments ##################################################################

deploy_arkivum()
{
    # Establish session
    session_get
    # Create security group
    local -r sg_id="$(aws_sg_create "${ARKIVUM_INSTANCE}")"
    # Enable SSH access
    aws_sg_authorize_ingress "${sg_id}" "tcp" "22" "0.0.0.0/0"
    # Import keypair
    aws_keypair_import "${ARKIVUM_INSTANCE}" "${SSH_KEY_PATH}"
    # Launch the instance
    log_info "Launching Arkivum appliance '${ARKIVUM_INSTANCE}' ..."
    local -r instance_id="$(aws_ec2_create_instance \
            "${ARKIVUM_INSTANCE}" \
            "arkivum" \
            "${ARKIVUM_3_AMI}" \
            "${ARKIVUM_INSTANCE_TYPE}" \
            "${ARKIVUM_INSTANCE}" \
            "${sg_id}" \
            "${SUBNET_ID:-$(aws_vpc_get_subnet "${VPC_ID}" 0)}" \
        )"
    log_info "Arkivum appliance '${ARKIVUM_INSTANCE}' has id '${instance_id}'"
    # Add a new public host entry for the instance
    local -r pub_ip="$(aws_ec2_get_public_ip_for_instance_name "${ARKIVUM_INSTANCE}")"
    aws_r53_add_host "${PUBLIC_HOSTED_ZONE}" "arkivum" "${pub_ip}"
}

deploy_containers() {
    # Use docker machine to run make to create the 'external' Docker volumes
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
        "cd ~/src/rdss-archivematica/compose && \
        sudo make create-volumes \
            AM_AUTOTOOLS_DATA=/mnt/am-autotools-data \
            AM_PIPELINE_DATA=/mnt/nfs/am-pipeline-data \
            ARK_STORAGE_DATA=/mnt/astor \
            ELASTICSEARCH_DATA=/mnt/elasticsearch-data \
            JISC_TEST_DATA=/mnt/s3/jisc-rdss-test-research-data \
            MINIO_EXPORT_DATA=/mnt/nfs/minio-export-data \
            MYSQL_DATA=/mnt/mysql-data \
            NEXTCLOUD_DATA=/mnt/nfs/nextcloud-data \
            NEXTCLOUD_THEMES=/mnt/nfs/nextcloud-themes \
            SS_LOCATION_DATA=/mnt/nfs/am-ss-default-location-data \
            SS_STAGING_DATA=/mnt/nfs/am-ss-staging-data"
    # Use docker machine to run make to deploy the containers
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
        "cd ~/src/rdss-archivematica/compose ; \
        export VOL_BASE=\$(pwd) ; \
        export DOMAIN_NAME=${PUBLIC_HOSTED_ZONE} ; \
        export DOMAIN_ORGANISATION=${DOMAIN_ORGANISATION} ; \
        export NGINX_EXTERNAL_IP='0.0.0.0' ; \
        export IDP_EXTERNAL_IP='0.0.0.0' ; \
        export IDP_EXTERNAL_PORT=4443 ; \
        export REGISTRY=localhost:5000/ ; \
            make all SHIBBOLETH_CONFIG=${SHIBBOLETH_CONFIG}"
    # Use docker machine to copy sample data from compose dev src to minio
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
        "sudo rsync -avz \
            ~/src/rdss-archivematica/compose/dev/s3/rdss-prod-figshare-0132/ \
            /mnt/nfs/minio-export-data/rdss-prod-figshare-0132/"
}

deploy_dockerhost()
{
    # Establish session
    session_get
    # Discover the private IP addresses for the Arkivum appliance and NFS server
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        local -r arkivum_host=$(aws_ec2_get_private_ip_for_instance_name "${ARKIVUM_INSTANCE}")
        if [ -z "${arkivum_host}" ] ; then
            log_fatal "Unable to detect IP address for Arkivum appliance. Ensure ${ARKIVUM_INSTANCE} exists in AWS."
        fi
    fi
    local -r nfs_host=$(aws_ec2_get_private_ip_for_instance_name "${NFS_INSTANCE}")
    if [ -z "$nfs_host" ] ; then
        log_fatal "Unable to detect IP address for NFS server. Ensure ${NFS_INSTANCE} exists in AWS."
    fi
    # Check that we have parameters for connecting to the Jisc S3 bucket
    if [ -z "${S3_BUCKET_PARAMS}" ] ; then
        log_fatal "Required env var S3_BUCKET_PARAMS not defined."
    fi
    # Provision the machine, check dependencies, mount volumes, prepare images
    # and repos, and then deploy the containers
    docker_machine_provision && \
        check_dockerhost_dependencies && \
        remote_mount_nfs "${nfs_host}" && \
        remote_mount_s3fs "${S3_BUCKET_PARAMS}" && \
        docker_check_registry && \
        prepare_dockerhost && \
        deploy_containers
    if [ "${CLOUDWATCH_ENABLED}" == "true" ]; then
        #Configure Cloudwatch on docker-host
        docker_machine_configure_cloudwatch
    fi
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        # Add the Arkivum mount to the docker host
        remote_mount_arkivum "${arkivum_host}"
    fi
    # Get the ports for each exposed service
    local am_dash_port
    local am_ss_port
    local nextcloud_port
    local shib_idp_port
    am_dash_port="$(docker_get_service_port 'nginx' 80)"
    am_ss_port="$(docker_get_service_port 'nginx' 8000)"
    nextcloud_port="$(docker_get_service_port 'nextcloud' 8888)"
    if [ "${SHIB_ENABLED}" == "true" ] ; then
        # Dash, SS and NextCloud use the same port with Shibboleth enabled
        am_dash_port="$(docker_get_service_port 'nginx-ssl' 443)"
        am_ss_port="${am_dash_port}"
        nextcloud_port="${am_dash_port}"
        shib_idp_port="$(docker_get_service_port 'idp' 4443)"
    fi
    # Add ingress rule for each of the exposed services
    local -r sg_id="$(aws_sg_get "${DOCKERHOST_INSTANCE}")"
    aws_sg_authorize_ingress "${sg_id}" "tcp" "${am_dash_port}" "0.0.0.0/0"
    aws_sg_authorize_ingress "${sg_id}" "tcp" "${am_ss_port}" "0.0.0.0/0"
    aws_sg_authorize_ingress "${sg_id}" "tcp" "${nextcloud_port}" "0.0.0.0/0"
    if [ "${SHIB_ENABLED}" == "true" ] ; then
        aws_sg_authorize_ingress "${sg_id}" "tcp" "${shib_idp_port}" "0.0.0.0/0"
    fi
    # Add a private hosts entry for the docker host
    local -r priv_ip="$(aws_ec2_get_private_ip_for_instance_name "${DOCKERHOST_INSTANCE}")"
    aws_r53_add_host "${PRIVATE_HOSTED_ZONE}" "dockerhost" "${priv_ip}"
    # Add aliases and services for Archivematica
    if [ "${SHIB_ENABLED}" == "true" ] ; then
        aws_r53_add_host_alias "${PRIVATE_HOSTED_ZONE}" \
            "dashboard.archivematica" "dockerhost.${PRIVATE_HOSTED_ZONE}"
        aws_r53_add_host_alias "${PRIVATE_HOSTED_ZONE}" \
            "ss.archivematica" "dockerhost.${PRIVATE_HOSTED_ZONE}"
        aws_r53_add_service "${PRIVATE_HOSTED_ZONE}" \
            "am_dashboard" "${am_dash_port}" "tcp" "dashboard.archivematica.${PRIVATE_HOSTED_ZONE}"
        aws_r53_add_service "${PRIVATE_HOSTED_ZONE}" \
            "am_storage_service" "${am_ss_port}" "tcp" "ss.archivematica.${PRIVATE_HOSTED_ZONE}"
    else
        aws_r53_add_host_alias "${PRIVATE_HOSTED_ZONE}" \
            "archivematica" "dockerhost.${PRIVATE_HOSTED_ZONE}"
        aws_r53_add_service "${PRIVATE_HOSTED_ZONE}" \
            "am_dashboard" "${am_dash_port}" "tcp" "archivematica.${PRIVATE_HOSTED_ZONE}"
        aws_r53_add_service "${PRIVATE_HOSTED_ZONE}" \
            "am_storage_service" "${am_ss_port}" "tcp" "archivematica.${PRIVATE_HOSTED_ZONE}"
    fi
    # Add alias and service for NextCloud, if required
    aws_r53_add_host_alias "${PRIVATE_HOSTED_ZONE}" \
        "nextcloud" "dockerhost.${PRIVATE_HOSTED_ZONE}"
    aws_r53_add_service "${PRIVATE_HOSTED_ZONE}" \
        "nextcloud" "${nextcloud_port}" "tcp" "nextcloud.${PRIVATE_HOSTED_ZONE}"
    # Add alias and services for Shibboleth, if required
    if [ "${SHIB_ENABLED}" == "true" ] ; then
        aws_r53_add_host_alias "${PRIVATE_HOSTED_ZONE}" \
            "idp" "dockerhost.${PRIVATE_HOSTED_ZONE}"
        aws_r53_add_service "${PRIVATE_HOSTED_ZONE}" \
            "idp" "${shib_idp_port}" "tcp" "idp.${PRIVATE_HOSTED_ZONE}"
    fi
    # Add public service entries for each of the externally accessible services
    local -r pub_ip="$(aws_ec2_get_public_ip_for_instance_name "${DOCKERHOST_INSTANCE}")"
    aws_r53_add_host "${PUBLIC_HOSTED_ZONE}" "nextcloud" "${pub_ip}"
    if [ "${SHIB_ENABLED}" == "true" ] ; then
        aws_r53_add_host "${PUBLIC_HOSTED_ZONE}" "dashboard.archivematica" "${pub_ip}"
        aws_r53_add_host "${PUBLIC_HOSTED_ZONE}" "ss.archivematica" "${pub_ip}"
        aws_r53_add_host "${PUBLIC_HOSTED_ZONE}" "idp" "${pub_ip}"
    else
        aws_r53_add_host "${PUBLIC_HOSTED_ZONE}" "archivematica" "${pub_ip}"
    fi
}

deploy_hosted_zones()
{
    # Establish session
    session_get
    # Deploy the private hosted zone
    aws_r53_create_private_zone "${VPC_ID}" "${PRIVATE_HOSTED_ZONE}"
    # Deploy the public hosted zone
    aws_r53_create_public_zone "${PUBLIC_HOSTED_ZONE}"
}

deploy_nfs_server()
{
    # Establish session
    session_get
    # Create security group
    local -r sg_id="$(aws_sg_create "${NFS_INSTANCE}")"
    # Enable SSH access
    aws_sg_authorize_ingress "${sg_id}" "tcp" "22" "0.0.0.0/0"
    # Enable global access from other instances in the same VPC
    aws_sg_authorize_ingress "${sg_id}" "tcp" "0-65535" \
        "$(aws_vpc_get_cidr "${VPC_ID}")"
    # Import keypair
    aws_keypair_import "${NFS_INSTANCE}" "${SSH_KEY_PATH}"
    # Launch the instance
    log_info "Launching NFS server '${NFS_INSTANCE}' ..."
    local -r instance_id="$(aws_ec2_create_instance \
            "${NFS_INSTANCE}" \
            "nfs" \
            "${NFS_SERVER_AMI}" \
            "${NFS_INSTANCE_TYPE}" \
            "${NFS_INSTANCE}" \
            "${sg_id}" \
            "${SUBNET_ID:-$(aws_vpc_get_subnet "${VPC_ID}" 0)}" \
            "file://${NFS_USERDATA:-etc/userdata/nfs}" \
        )"
    log_info "NFS server '${NFS_INSTANCE}' has id '${instance_id}'"
    local -r volume_name="${NFS_INSTANCE}-data"
    local volume_id
    volume_id="$(aws_ec2_get_id_for_volume_name "${volume_name}")"
    if [ "${volume_id}" == "" ] ; then
        # Create a new EBS volume for data storage
        log_info "Creating EBS volume '${volume_name}' ..."
        volume_id=$(aws ec2 create-volume \
            --size "${NFS_STORAGE_SIZE}" \
            --region "${AWS_REGION}" \
            --availability-zone "${AWS_REGION}a" \
            --volume-type "${NFS_STORAGE_VOLUME_TYPE}" \
            --query 'VolumeId' \
            --output text)
        # Tag the created resource to allow us to identify it
        aws_ec2_tag_resource "${volume_id}" \
            "${volume_name}" "${PROJECT_ID}" "${ENVIRONMENT}"
    fi
    log_info "NFS server volume '${volume_name}' has id '${volume_id}'"
    # Check if the volume is attached
    local -r vol_attached_ids="$(aws_ec2_get_volume_attached_instance_ids "${volume_id}")"
    if [ "$(echo "${vol_attached_ids}" | grep "${instance_id}")" == "" ] ; then
        # Wait for the instance to be "running"
        local instance_state
        while [ "$instance_state" != "available" ] ; do
            instance_state="$(aws_ec2_get_instance_state "${instance_id}")"
            case $instance_state in
                running)
                    log_info "Instance is now running."
                    break
                    ;;
                *)
                    log_info "Instance state is '${instance_state}', waiting..."
                    sleep 2
                    ;;
            esac
        done
        # Wait for the volume to become "available"
        local volume_state=""
        while [ "$volume_state" != "available" ] ; do
            volume_state="$(aws_ec2_get_volume_state "${volume_id}")"
            case $volume_state in
                available)
                    log_info "Volume is now available."
                    break
                    ;;
                *)
                    log_info "Volume state is '${volume_state}', waiting..."
                    sleep 2
                    ;;
            esac
        done
        # Attach the EBS volume to NFS server instance
        log_info "Attaching volume '${volume_name}' to '${NFS_INSTANCE}' ..."
        aws ec2 attach-volume \
            --device '/dev/xvdf' \
            --instance-id "${instance_id}" \
            --volume-id "${volume_id}"
        log_info "Attached volume '${volume_name}' to '${NFS_INSTANCE}'."
    else
        log_info "Volume '${volume_name}' already attached to instance '${NFS_INSTANCE}'."
    fi
}

# Clones the rdss-archivematica repo and uses Ansible to build and deploy the
# container images to the local registry on the remote host, ready for use by
# the docker-compose instantiation process
prepare_dockerhost()
{
    # Clone compose repo and run build playbooks in the remote Docker host
    # shellcheck disable=SC2088
    local -r clone_dir="~/src/rdss-archivematica"
    log_info "Cloning ${clone_dir} and publishing images ..."
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
        "sudo rm -Rf ${clone_dir} && mkdir -p ${clone_dir} && \
            git clone --branch '${RDSSARK_VERSION}' \
                ${RDSS_ARCHIVEMATICA_REPO} ${clone_dir} && \
            cd ${clone_dir} && make publish REGISTRY=localhost:5000/"
}

# Entrypoint ###################################################################

main()
{
    log_info "RDSSARK Deployment Script starting..."
    log_info "The following branch or version will be used: ${RDSSARK_VERSION}"
    log_info "The following AWS parameters will be used:"
    log_info "  MFA enabled: ${MFA_AUTH_ENABLED}"
    log_info "  Region     : ${AWS_REGION}"
    log_info "  VPC Id     : ${VPC_ID}"
    log_info "  Subnet Id  : ${SUBNET_ID:-auto}"
    log_info "The following hosted zones will be deployed:"
    log_info "  Private: ${PRIVATE_HOSTED_ZONE}"
    log_info "  Public : ${PUBLIC_HOSTED_ZONE}"
    log_info "The following instances will be deployed:"
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        log_info "  Arkivum appliance: ${ARKIVUM_INSTANCE}"
    fi
    log_info "  NFS server:        ${NFS_INSTANCE}"
    log_info "  Docker host:       ${DOCKERHOST_INSTANCE}"
    log_info "The following application security parameters will be used:"
    log_info "  Deployment Domain: ${DOMAIN_ORGANISATION}"
    log_info "  Shibboleth Config: ${SHIBBOLETH_CONFIG}"
    log_info "The following services will be deployed:"
    local am_dash_url
    local am_ss_url
    local nextcloud_url
    am_dash_url="http://archivematica.${PUBLIC_HOSTED_ZONE}:<dynamic-port>/"
    am_ss_url="http://archivematica.${PUBLIC_HOSTED_ZONE}:<dynamic-port>/"
    nextcloud_url="http://nextcloud.${PUBLIC_HOSTED_ZONE}:8888/"
    if [ "${SHIB_ENABLED}" == "true" ] ; then
        # With Shibboleth enabled the ports are fixed and HTTPS is used
        am_dash_url="https://dashboard.archivematica.${PUBLIC_HOSTED_ZONE}/"
        am_ss_url="https://ss.archivematica.${PUBLIC_HOSTED_ZONE}/"
        nextcloud_url="https://nextcloud.${PUBLIC_HOSTED_ZONE}/"
    fi
    log_info "  Archivematica Dashboard:       ${am_dash_url}"
    log_info "  Archivematica Storage Service: ${am_ss_url}"
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        log_info "  Arkivum appliance:             https://arkivum.${PUBLIC_HOSTED_ZONE}:8443/"
    fi
    log_info "  NextCloud:                     ${nextcloud_url}"
    log_info "  RDSS Archivematica MsgCreator: ${am_dash_url}msgcreator"
    log_note "If this looks incorrect, abort now using CTRL+C ..."
    sleep 10
    log_info ">>>>>> DEPLOYING >>>>>"
    # Deploy the hosted zones
    deploy_hosted_zones
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        # Deploy the Arkivum appliance
        deploy_arkivum
    fi
    # Deploy the NFS server used as shared storage
    deploy_nfs_server
    # Deploy the docker host that will run Archivematica and NextCloud
    deploy_dockerhost
    log_info "<<<<<< DEPLOYMENT COMPLETE <<<<<"
    log_info "Deployed instances:"
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        local -r arkivum_ip="$(aws_ec2_get_public_ip_for_instance_name "${ARKIVUM_INSTANCE}")"
        log_info "  Arkivum appliance: ${arkivum_ip} / ${ARKIVUM_INSTANCE}"
    fi
    local -r dockerhost_ip="$(aws_ec2_get_public_ip_for_instance_name "${DOCKERHOST_INSTANCE}")"
    log_info "  Docker host      : ${dockerhost_ip} / ${DOCKERHOST_INSTANCE}"
    local -r nfs_ip="$(aws_ec2_get_public_ip_for_instance_name "${NFS_INSTANCE}")"
    log_info "  NFS server       : ${nfs_ip} / ${NFS_INSTANCE}"
    log_info "Deployed services:"
    if [ "${SHIB_ENABLED}" != "true" ] ; then
        # With Shibboleth disabled the ports are dynamic and HTTP is used
        local -r am_dash_port="$(docker_get_service_port 'nginx' 80)"
        local -r am_ss_port="$(docker_get_service_port 'nginx' 8000)"
        am_dash_url="http://archivematica.${PUBLIC_HOSTED_ZONE}:${am_dash_port}/"
        am_ss_url="http://archivematica.${PUBLIC_HOSTED_ZONE}:${am_ss_port}/"
    fi
    log_info "  Archivematica Dashboard:       ${am_dash_url}"
    log_info "  Archivematica Storage Service: ${am_ss_url}"
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        log_info "  Arkivum appliance:             https://arkivum.${PUBLIC_HOSTED_ZONE}:8443/"
    fi
    log_info "  NextCloud:                     ${nextcloud_url}"
    log_info "  RDSS Archivematica MsgCreator: ${am_dash_url}msgcreator"
    local -r public_ns="$(aws_r53_get_zone_ns "${PUBLIC_HOSTED_ZONE}")"
    log_info "The following NS records must be added to DNS for ${PUBLIC_DOMAIN_NAME}:"
    log_info "  ${public_ns}"
    log_info "Done."
}

main "$@"
