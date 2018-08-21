#!/bin/bash

#
# Tears down all of the resources associated with a deployed Arkivum appliance,
# NFS server and dockerhost. May also optionally destroy storage volumes too.
#
# Usage:
#
# To override the project id for the resources to tear down
#    PROJECT_ID=1234 ./teardown.sh
#
# To also remove the EBS storage used by the NFS server (removing ALL data!)
#    DESTROY_VOLUMES=yes PROJECT_ID=1234 ./teardown.sh
#
# To also remove the CloudWatch log group
#    DESTROY_VOLUMES=yes DESTROY_CLOUDWATCH_LOG=yes PROJECT_ID=1234 ./teardown.sh


# shellcheck disable=SC2034
PROGNAME="$(basename "${BASH_SOURCE[0]}" | cut -d. -f1)"
SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

# Include library modules
# shellcheck source=./lib/libs.sh
source "${SCRIPT_DIR}/lib/libs.sh"

# Tear down ####################################################################

destroy_containers() {
    # Use make to destroy the containers and their non-external volumes
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
        "if [ -e ~/src/rdss-archivematica/compose ] ; then \
            cd ~/src/rdss-archivematica/compose ; \
            export VOL_BASE=\$(pwd) ; \
            export DOMAIN_NAME=${PUBLIC_DOMAIN_NAME} ; \
            export DOMAIN_ORGANISATION=${DOMAIN_ORGANISATION} ; \
            export NGINX_EXTERNAL_IP='0.0.0.0' ; \
            export IDP_EXTERNAL_IP='0.0.0.0' ; \
            export IDP_EXTERNAL_PORT=4443 ; \
                make destroy \
                    SHIBBOLETH_CONFIG=${SHIBBOLETH_CONFIG} \
                    NEXTCLOUD_ENABLED=true ; \
        fi"
}

teardown_arkivum()
{
    log_info "Destroying Arkivum appliance '${ARKIVUM_INSTANCE}' ..."
    # Establish session
    session_get
    # Get the IP of the existing instance(s), if any
    local -r instance_id="$(aws_ec2_get_id_for_instance_name "${ARKIVUM_INSTANCE}")"
    # Destroy the instance(s)
    # shellcheck disable=SC2001
    for i_id in $(echo "${instance_id}" | sed 's/$/ /g') ; do
        aws_ec2_terminate_instance "${i_id}"
    done
    # Destroy the security group
    aws_sg_remove "${ARKIVUM_INSTANCE}"
    # Remove keypair
    aws_keypair_remove "${ARKIVUM_INSTANCE}" "${SSH_KEY_PATH}"
    log_info "Arkivum appliance '${ARKIVUM_INSTANCE}' has been destroyed."
}

teardown_channel_adapter_resources()
{
    # Establish session
    session_get
    # Delete DynamoDB tables
    aws_dynamodb_delete_table "${RDSS_ADAPTER_TABLE_CHECKPOINTS}"
    aws_dynamodb_delete_table "${RDSS_ADAPTER_TABLE_CLIENTS}"
    aws_dynamodb_delete_table "${RDSS_ADAPTER_TABLE_METADATA}"
    aws_dynamodb_delete_table "${RDSS_ADAPTER_BROKER_REPOSITORY_DYNAMODB_TABLE}"
    aws_dynamodb_delete_table "${RDSS_ADAPTER_CONSUMER_DYNAMODB_TABLE}"
    if [ ! -z "${DESTROY_KINESIS_QUEUES}" ] ; then
       # Delete Kinesis streams
       aws_kinesis_delete_stream "${RDSS_ADAPTER_QUEUE_ERROR}"
       aws_kinesis_delete_stream "${RDSS_ADAPTER_QUEUE_INPUT}"
       aws_kinesis_delete_stream "${RDSS_ADAPTER_QUEUE_INVALID}"
       aws_kinesis_delete_stream "${RDSS_ADAPTER_QUEUE_OUTPUT}"
    fi
}

teardown_dockerhost()
{
    log_info "Destroying Docker host '${DOCKERHOST_INSTANCE}' ..."
    # Establish session
    session_get
    # Get the IP of the existing instance, if any
    local -r instance_id="$(aws_ec2_get_id_for_instance_name "${DOCKERHOST_INSTANCE}")"
    if [ "${instance_id}" != "" ] ; then
        # Destroy the containers and stop the dockerhost
        destroy_containers
        docker_machine_stop "${DOCKERHOST_INSTANCE}"
    fi
    # Remove the docker machine entirely - even if there is no instance running
    docker_machine_remove "${DOCKERHOST_INSTANCE}"
    log_info "Docker host '${DOCKERHOST_INSTANCE}' has been destroyed."
}

teardown_hosted_zones()
{
# Establish session
    session_get
    # Remove all records from the public zone.
    aws_r53_remove_zone_records "${PUBLIC_HOSTED_ZONE}"
    # Remove the public hosted zone. It should be empty after we have removed
    # all other services.
    aws_r53_remove_zone "${PUBLIC_HOSTED_ZONE}"
    # Remove all records from the private zone.
    aws_r53_remove_zone_records "${PRIVATE_HOSTED_ZONE}"
    # Remove the private hosted zone. It should be empty after we have removed
    # all other services.
    aws_r53_remove_zone "${PRIVATE_HOSTED_ZONE}"
}

teardown_nfs_server()
{
    log_info "Destroying NFS server '${NFS_INSTANCE}' ..."
    # Establish session
    session_get
    # Get the IP of the existing instance, if any
    local -r instance_id=$(aws_ec2_get_id_for_instance_name "${NFS_INSTANCE}")
    # Destroy the instance(s)
    # shellcheck disable=SC2001
    for i_id in $(echo "${instance_id}" | sed 's/$/ /g') ; do
        aws_ec2_terminate_instance "${i_id}"
    done
    # Destroy the security group
    aws_sg_remove "${NFS_INSTANCE}"
    # Remove keypair
    aws_keypair_remove "${NFS_INSTANCE}" "${SSH_KEY_PATH}"
    if [ "${DESTROY_VOLUMES}" != "" ] ; then
        # Destroy the EBS data volume
        local -r volume_name="${NFS_INSTANCE}-data"
        local -r volume_id="$(aws_ec2_get_id_for_volume_name "${volume_name}")"
        if [ "${volume_id}" != "" ] ; then
            log_info "Deleting volume '${volume_name}' ..."
            aws ec2 delete-volume --volume-id "${volume_id}"
            log_info "Deleted volume '${volume_name}'."
        fi
    fi
    log_info "NFS server '${NFS_INSTANCE}' has been destroyed."
}

# Entrypoint ###################################################################

main()
{
    log_info "RDSSARK Teardown Script starting..."
    log_info "The following AWS parameters will be used:"
    log_info "  MFA enabled: ${MFA_AUTH_ENABLED}"
    log_info "  Region     : ${AWS_REGION}"
    log_info "  VPC Id     : ${VPC_ID}"
    log_info "  Subnet Id  : ${SUBNET_ID:-auto}"
    log_info "The following instances will be torn down:"
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        log_info "  Arkivum appliance: ${ARKIVUM_INSTANCE}"
    fi
    log_info "  NFS server       : ${NFS_INSTANCE}"
    log_info "  Docker host      : ${DOCKERHOST_INSTANCE}"
    log_info "The following hosted zones will be removed:"
    log_info "  Private: ${PRIVATE_HOSTED_ZONE}"
    log_info "  Public : ${PUBLIC_HOSTED_ZONE}"
    if [ "${DESTROY_VOLUMES}" != "" ] ; then
        log_alert "DESTROY_VOLUMES IS SET - ALL DATA WILL BE DESTROYED!!!"
        log_alert "Abort now using CTRL+C if you do not wish to do this!!"
        sleep 20
        log_alert "Timeout passed - this script will remove all data!"
    fi
    log_info ">>>>>> TEARING DOWN >>>>>"
    # Tear down the docker host that runs Archivematica and NextCloud
    teardown_dockerhost
    # Tear down the NFS server used as shared storage
    teardown_nfs_server
    if [ ! -z "${ARKIVUM_ENABLED}" ] ; then
        # Tear down the Arkivum appliance
        teardown_arkivum
    fi
    if [ "${RDSS_ADAPTER_CREATE_AWS_RESOURCES}" = "true" ] ; then
        # Tear down Channel Adapter resources
        teardown_channel_adapter_resources
    fi
    # Tear down the hosted zones
    teardown_hosted_zones
    # Remove CloudWatch log-group if DESTROY_CLOUDWATCH_LOG is enabled
    if [ ! -z "${DESTROY_CLOUDWATCH_LOG}" ] ; then
        log_alert "DESTROY_CLOUDWATCH IS SET - LOG GROUP WILL BE DESTROYED!!!"
        aws logs delete-log-group --log-group-name "${PROJECT_ID}-${ENVIRONMENT}"
    fi
    log_info "<<<<<< TEAR DOWN COMPLETE <<<<<"
    log_info "Done."
}

main "$@"
