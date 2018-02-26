#!/bin/bash

#
# Functions related to remote docker and docker machine operations.
#

# Only load this library once
if [ -z "${_LIB_DOCKER_SH}" ] ; then

LIB_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

# Include dependencies

# shellcheck source=./lib/lib-aws.sh
source "${LIB_DIR}/lib-aws.sh"

# shellcheck source=./lib/lib-config.sh
source "${LIB_DIR}/lib-config.sh"

# Docker #######################################################################

# Checks that required dependencies are installed on the remote Docker host
check_dockerhost_dependencies()
{
    # See http://docs.ansible.com/ansible/latest/intro_installation.html#latest-releases-via-apt-ubuntu
    # We also include:
    #  - cifs-utils
    #  - make
    #  - nfs-common
    #  - python-pip
    #  - s3fs
    # We also make the `ubuntu` user part of the `docker` group
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
        "sudo apt-add-repository -y ppa:ansible/ansible && \
        sudo apt update && \
        sudo apt install -y \
            ansible \
            cifs-utils \
            make \
            nfs-common \
            python-pip \
            s3fs \
            software-properties-common && \
        sudo usermod -a -G docker ubuntu && \
        sudo -H pip install -U pip && \
        sudo -H pip install docker-compose==${DOCKER_COMPOSE_VERSION:-1.17.0}"
}

# Checks, and if necessary creates, a registry on the remote Docker host.
docker_check_registry()
{
    local registry_url="http://localhost:5000"
    while [ "$(docker-machine ssh "${DOCKERHOST_INSTANCE}" \
            curl -s "${registry_url}/v2/" >/dev/null 2>&1 ; echo $?)" -eq 1 ] ; do
        log_info "Docker Registry unavailable, creating"
        # Set Docker to use our EC2 instance and build and run the containers
        eval "$(docker-machine env "${DOCKERHOST_INSTANCE}")"
        # Create the registry
        docker run -d -p 5000:5000 --name registry registry:2
    done
    log_info "Docker Registry is ready and available at ${registry_url}."
}

# Gets the public port for the given service name and private port.
docker_get_service_port()
{
    local -r service="$1"
    local -r private_port="$2"
    local compose_files
    compose_files="docker-compose.qa.yml:docker-compose.nextcloud.yml"
    if [ "${SHIB_ENABLED}" == "true" ] ; then
        compose_files="${compose_files}:docker-compose.am-shib.yml"
        compose_files="${compose_files}:docker-compose.shib-local.yml"
    fi
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
        "cd ~/src/rdss-archivematica/compose && \
            export COMPOSE_FILE=${compose_files} ; \
            docker-compose port ${service} ${private_port} | cut -d: -f2"
}

# Gets the current status of the remote Docker host. If the host is currently
# starting or stopping then this will block and wait until it enters a stable
# state.
docker_machine_get_status()
{
    docker_machine_wait_for_status "Starting Stopping"
}

# Provisions or restarts the remote Docker host machine.
docker_machine_provision()
{
    local machine_status
    local instance_id
    instance_id="$(aws_ec2_get_id_for_instance_name "${DOCKERHOST_INSTANCE}")"
    if [ "${instance_id}" == "" ] ; then
        # No instance exists, don't bother asking for status
        machine_status="NotExist"
    else
        # Instance exists, check status
        machine_status="$(docker_machine_get_status)"
    fi
    case $machine_status in
        "Error")
            # Unknown error, abort
            log_error "Unknown error whilst provisioning ${DOCKERHOST_INSTANCE}, exiting."
            return 1
            ;;
        "NotExist")
            # Provision new EC2 instance to run docker
	    if [ "${CLOUDWATCH_ENABLED}" == "true" ] ; then
                docker-machine create \
                    --driver amazonec2 \
                    --amazonec2-region "${AWS_REGION}" \
                    --amazonec2-instance-type "${DOCKERHOST_INSTANCE_TYPE}" \
                    --amazonec2-iam-instance-profile "${IAM_PROFILE}" \
                    --amazonec2-root-size "${DOCKERHOST_ROOT_SIZE:-16}" \
                    --amazonec2-security-group "${DOCKERHOST_INSTANCE}" \
                    --amazonec2-ssh-keypath "${SSH_KEY_PATH}" \
                    --amazonec2-tags \
                        "Name,${DOCKERHOST_INSTANCE},Environment,${ENVIRONMENT},ProjectId,${PROJECT_ID}" \
                    --amazonec2-vpc-id "${VPC_ID}" \
                    --engine-opt log-driver=awslogs \
                    --engine-opt log-opt="awslogs-region=${AWS_REGION}" \
                    --engine-opt log-opt="awslogs-group=${PROJECT_ID}-${ENVIRONMENT}" \
                    --engine-opt log-opt="awslogs-create-group=true" \
                    --engine-opt log-opt="tag='{{.Name}}'" \
		"${DOCKERHOST_INSTANCE}" && docker_machine_wait_for_status "Starting"
            else
	        docker-machine create \
                    --driver amazonec2 \
                    --amazonec2-region "${AWS_REGION}" \
                    --amazonec2-instance-type "${DOCKERHOST_INSTANCE_TYPE}" \
                    --amazonec2-iam-instance-profile "${IAM_PROFILE}" \
                    --amazonec2-root-size "${DOCKERHOST_ROOT_SIZE:-16}" \
                    --amazonec2-security-group "${DOCKERHOST_INSTANCE}" \
                    --amazonec2-ssh-keypath "${SSH_KEY_PATH}" \
                    --amazonec2-tags \
                        "Name,${DOCKERHOST_INSTANCE},Environment,${ENVIRONMENT},ProjectId,${PROJECT_ID}" \
                    --amazonec2-vpc-id "${VPC_ID}" \
                    --engine-storage-driver overlay2 \
                "${DOCKERHOST_INSTANCE}" && docker_machine_wait_for_status "Starting"
            fi
            instance_id="$(aws_ec2_get_id_for_instance_name "${DOCKERHOST_INSTANCE}")"
            log_debug "Dockerhost '${DOCKERHOST_INSTANCE}' has instance id '${instance_id}'"
            # If we got an instance id (or ids) then iterate through them to confirm
            # they are or it is in a running state (multiple ids can happen if instances
            # are stopped/started in quick succession or if a AWS limit is hit).
            # shellcheck disable=SC2001
            for i_id in $(echo "${instance_id}" | sed "s/$/ /g") ; do
                local i_state
                i_state="$(aws_ec2_get_instance_state "${i_id}")"
                if [ "${i_state}" != "running" ] ; then
                    # Remove the instance from the instance ids list
                    log_debug "Instance ${i_id} is in state ${i_state}, ignoring."
                    instance_id="$(echo "${instance_id}" | sed "s/${i_id}//")"
                fi
            done
            # Tag the volume(s) created by docker-machine
            local -r vol_ids="$(aws_ec2_get_instance_attached_volumes "${instance_id}")"
            local vol_index
            vol_index=0
            for v_id in $vol_ids ; do
                aws_ec2_tag_resource "${v_id}" \
                    "${DOCKERHOST_INSTANCE}-disk-${vol_index}" "${PROJECT_ID}" "${ENVIRONMENT}"
                    vol_index="$((vol_index + 1))"
            done
            # Also tag the security group created by docker-machine
            local -r sg_id="$(aws_sg_get "${DOCKERHOST_INSTANCE}")"
            aws_ec2_tag_resource "${sg_id}" \
                    "${DOCKERHOST_INSTANCE}" "${PROJECT_ID}" "${ENVIRONMENT}"
            ;;
        "Stopped")
            # Start existing EC2 instance again ready for use
            docker-machine start "${DOCKERHOST_INSTANCE}" && \
                docker_machine_get_status
            # Regenerate certs because the IP address will have changed
            docker-machine regenerate-certs -f "${DOCKERHOST_INSTANCE}"
            ;;
        "Running")
            # EC2 instance already running, nothing to do
            log_info "${DOCKERHOST_INSTANCE} already running..."
            ;;
        "UnauthorizedOperation")
            # User doesn't have authority for this operation
            log_error "Insufficient access to provision ${DOCKERHOST_INSTANCE}, exiting."
            return 1
            ;;
        *)
            log_error "Unhandled machine status '$machine_status' in provision"
            return 1
            ;;
    esac
}

# Stops the remote Docker host machine.
docker_machine_stop()
{
    local machine_status
    local -r instance_id="$(aws_ec2_get_id_for_instance_name "${DOCKERHOST_INSTANCE}")"
    if [ "${instance_id}" == "" ] ; then
        # No instance exists, don't bother asking for status
        machine_status="NotExist"
    else
        # Instance exists, check status
        machine_status="$(docker_machine_get_status)"
    fi
    case $machine_status in
        "Error")
            # Unknown error, abort
            log_fatal "Unknown error whilst stopping ${DOCKERHOST_INSTANCE}, exiting."
            ;;
        "NotExist")
            # EC2 instance doesn't exist, nothing to do
            log_debug "${DOCKERHOST_INSTANCE} doesn't exist, nothing to stop."
            ;;
        "Stopped")
            # EC2 instance already stopped, nothing to do
            log_info "${DOCKERHOST_INSTANCE} already stopped, nothing to do."
            ;;
        "Running")
            # EC2 instance running, stop it
            log_info "${DOCKERHOST_INSTANCE} is running, stopping..."
            docker-machine stop "${DOCKERHOST_INSTANCE}" && \
                docker_machine_get_status
            ;;
        "UnauthorizedOperation")
            # User doesn't have authority for this operation
            log_fatal "Insufficient access to stop ${DOCKERHOST_INSTANCE}, exiting."
            ;;
        *)
            log_fatal "Unhandled machine status '$machine_status' in stop"
            ;;
    esac
}

# Removes the remote Docker host machine. It does not force removal if the
# instance is still running.
docker_machine_remove()
{
    local machine_status
    local -r instance_id="$(aws_ec2_get_id_for_instance_name "${DOCKERHOST_INSTANCE}")"
    if [ "${instance_id}" == "" ] ; then
        # No instance exists, don't bother asking for status
        machine_status="NotExist"
    else
        # Instance exists, check status
        machine_status="$(docker_machine_get_status)"
    fi
    case $machine_status in
        "Error")
            # Unknown error, abort
            log_fatal "Unknown error whilst removing ${DOCKERHOST_INSTANCE}, exiting."
            ;;
        "NotExist")
            # EC2 instance doesn't exist
            if [ -e "${HOME}/.docker/machine/machines/${DOCKERHOST_INSTANCE}/" ] ; then
                # Docker machine still has local reference to the instance, remove it
                log_info "${DOCKERHOST_INSTANCE} no longer exists, removing..."
                docker-machine rm -y "${DOCKERHOST_INSTANCE}" \
                    && docker_machine_wait_for_status "Stopping"
            fi
            # Destroy the security group, if it still exists
            aws_sg_destroy "${DOCKERHOST_INSTANCE}"
            ;;
        "Stopped")
            # EC2 instance stopped, remove it
            log_info "${DOCKERHOST_INSTANCE} is stopped, removing..."
            docker-machine rm -y "${DOCKERHOST_INSTANCE}" \
                && docker_machine_wait_for_status "Stopping"
            # Also ensure that the security group is destroyed
            aws_sg_destroy "${DOCKERHOST_INSTANCE}"
            ;;
        "Running")
            # EC2 instance running, can't remove
            log_fatal "${DOCKERHOST_INSTANCE} is still running, cannot remove, aborting."
            ;;
        "UnauthorizedOperation")
            # User doesn't have authority for this operation
            log_fatal "Insufficient access to remove ${DOCKERHOST_INSTANCE}, exiting."
            ;;
        *)
            log_fatal "Unhandled machine status '$machine_status' in remove"
            ;;
    esac
}

# Updates the Docker Machine amazonec2 driver authentication config. This is
# necessary to avoid stale AWS session values being kept when a session is
# refreshed.
docker_machine_update_driver_auth_config()
{
    local dm_config_file="${HOME}/.docker/machine/machines/${DOCKERHOST_INSTANCE}/config.json"
    if [ -f "${dm_config_file}" ] ; then
        local tmp_file="/tmp/.docker-machine.config.tmp"
        # The Docker Machine config keeps stale AWS credentials, which result in
        # RequestExpired errors. We therefore update it when we refresh the session.
        sed -r "s|AccessKey\": \"[^\"]+|AccessKey\": \"${AWS_ACCESS_KEY_ID}|" "${dm_config_file}" | \
            sed -r "s|SecretKey\": \"[^\"]+|SecretKey\": \"${AWS_SECRET_ACCESS_KEY}|" | \
            sed -r "s|SessionToken\": \"[^\"]+|SessionToken\": \"${AWS_SESSION_TOKEN}|" \
            > "${tmp_file}"
        cp "${tmp_file}" "${dm_config_file}" \
            && rm "${tmp_file}"
    fi
}

# Blocks and waits until the remote Docker host reaches a state other than the
# given wait_states.
docker_machine_wait_for_status()
{
    local -r wait_states="$1"
    local status
    status="$(docker-machine status "${DOCKERHOST_INSTANCE}" 2>&1)"
    # Handle error conditions
    if echo "${status}" | grep -q 'UnauthorizedOperation' ; then
        # User account isn't authorized to execute this operations
        echo "UnauthorizedOperation"
        return 1
    fi
    if echo "${status}" | grep -q 'not exist' ; then
        # Machine instance doesn't exist
        echo "NotExist"
        return 1
    fi
    if echo "${status}" | grep -q 'error' ; then
        log_warn "Handling error: ${status}"
        if [ "$(echo "${status}" | grep 'RequestExpired')" != "" ] ; then
            log_warn "Current request has expired, renewing session"
            status="error:request-expired"
            session_refresh && docker_machine_wait_for_status "${wait_states}"
        fi
    fi
    # Wait for intermediate states to transition
    while [ "$(echo "${wait_states}" | grep "${status}")" != "" ] ; do
        log_info "$status ${DOCKERHOST_INSTANCE} ..."
        sleep 4
        status="$(docker-machine status "${DOCKERHOST_INSTANCE}" 2>&1)"
    done
    echo "${status}"
}

#Configure System log on the CloudWatch if enabled.
docker_machine_configure_cloudwatch()
{
    local -r tmp_awslog_conf="/tmp/awslogs.conf.docker-host"
    docker-machine scp etc/awslogs.conf.docker-host \
       "${DOCKERHOST_INSTANCE}":/tmp/awslogs.conf.docker-host
    sleep 10   
    docker-machine ssh "${DOCKERHOST_INSTANCE}" \
       "curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O && \
       sudo sed -i 's/log_group_template/${PROJECT_ID}-${ENVIRONMENT}/g' ${tmp_awslog_conf} && \
       sudo python ./awslogs-agent-setup.py -n -r ${AWS_REGION} -c ${tmp_awslog_conf} && \
       sudo service awslogs restart && \
       sudo update-rc.d awslogs defaults"
}

_LIB_DOCKER_SH="LOADED"
log_debug "Loaded lib-docker"
fi # END
