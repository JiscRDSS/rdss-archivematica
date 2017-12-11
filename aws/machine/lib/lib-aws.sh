#!/bin/bash

#
# Functions related to AWS based services and resource management.
#

# Only load this library once
if [ -z "${_LIB_AWS_SH}" ] ; then

LIB_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"

# Include dependencies
# shellcheck source=./lib/lib-config.sh
source "${LIB_DIR}/lib-config.sh"

# Amazon Web Services ##########################################################

# Attempts normal authentication with AWS, without Multi-Factor Authentication.
aws_auth()
{
    if [ -s "${MACHINE_CREDENTIALS_FILE}" ] ; then
        return
    fi
    log_info "No AWS session, authenticating..."
    # Create STS session using aws cli
    aws sts get-session-token --output text > "${MACHINE_CREDENTIALS_FILE}"
    # Make it so that no one else can read the credentials file
    chmod u=rw,o= "${MACHINE_CREDENTIALS_FILE}"
    log_info "Authenticated with AWS"
}

# Attempts full authentication with AWS, including Multi-Factor Authentication.
aws_auth_mfa()
{
    if [ -s "${MACHINE_CREDENTIALS_FILE}" ] ; then
        return
    fi
    log_info "No AWS session, requesting MFA authentication credentials..."
    # Read the MFA code from the user input
    local mfa_token
    read -r -p "MFA Code: " mfa_token
    # Create STS session using aws cli
    aws sts get-session-token \
       --output text \
       --serial-number "${MFA_DEVICE_ID}" \
       --token-code "${mfa_token}" > "${MACHINE_CREDENTIALS_FILE}"
    # Make it so that no one else can read the credentials file
    chmod u=rw,o= "${MACHINE_CREDENTIALS_FILE}"
    log_info "Authenticated with AWS"
}

aws_ec2_create_instance()
{
    local -r name="$1"
    local -r hostname="$2"
    local -r image_id="$3"
    local -r instance_type="$4"
    local -r key_name="$5"
    local -r sg_id="$6"
    local -r subnet_id="$7"
    local -r user_data="$8"
    # Establish session
    session_get
    # Get existing instance id, if any
    local instance_id
    instance_id="$(aws_ec2_get_id_for_instance_name "${name}")"
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
    instance_id="${instance_id// //}"
    if [ "${instance_id}" == "" ] ; then
        # Launch the instance
        log_info "Launching instance '${name}' ..."
        if [ "${user_data}" == "" ] ; then
            # Create the instance without any user data
            instance_id="$(aws ec2 run-instances \
                --image-id "${image_id}" \
                --count 1 \
                --instance-type "${instance_type}" \
                --key-name "${key_name}" \
                --security-group-ids "${sg_id}" \
                --subnet-id "${subnet_id}" \
                --associate-public-ip-address \
                --iam-instance-profile Name="${IAM_PROFILE}" \
                --query 'Instances[0].InstanceId' \
                --output text)"
        else
            # Create the instance with the specified user data
            instance_id="$(aws ec2 run-instances \
                --image-id "${image_id}" \
                --count 1 \
                --instance-type "${instance_type}" \
                --key-name "${key_name}" \
                --security-group-ids "${sg_id}" \
                --subnet-id "${subnet_id}" \
                --user-data "${user_data}" \
                --associate-public-ip-address \
                --iam-instance-profile Name="${IAM_PROFILE}" \
                --query 'Instances[0].InstanceId' \
                --output text)"
        fi
        if [ "${instance_id}" == "" ] ; then
            log_fatal "Failed to create instance for '${name}', aborting."
        fi
        # Tag the created instance and security group to allow us to identify them
        aws_ec2_tag_resource "${instance_id}" \
            "${name}" "${PROJECT_ID}" "${ENVIRONMENT}"
        aws_ec2_tag_resource "${sg_id}" \
            "${name}" "${PROJECT_ID}" "${ENVIRONMENT}"
        # Wait for the instance to initialize
        local instance_state
        instance_state="$(aws_ec2_get_instance_state "${instance_id}")"
        while [ "${instance_state}" != "running" ] ; do
            if [ "${instance_state}" == "terminated" ] || \
                [ "${instance_state}" == "terminating" ] || \
                [ "${instance_state}" == "shutting-down" ] ; then
                    # This instance is on the way down, abort
                    log_fatal "Instance '${instance_id}' is no longer running (${instance_state}), aborting."
            fi
            log_info "Waiting for instance '${instance_id}' to start (${instance_state})"
            sleep 10
            instance_state="$(aws_ec2_get_instance_state "${instance_id}")"
        done
        # Tag the volume(s) created by EC2 for the instance
            local -r vol_ids="$(aws_ec2_get_instance_attached_volumes "${instance_id}")"
            local vol_index
            vol_index=0
            for v_id in $vol_ids ; do
                aws_ec2_tag_resource "${v_id}" \
                    "${name}-disk-${vol_index}" "${PROJECT_ID}" "${ENVIRONMENT}"
                vol_index="$((vol_index + 1))"
            done
        # Add a new private host entry for the instance
        local -r priv_ip="$(aws_ec2_get_private_ip_for_instance_name "${name}")"
        local -r pub_ip="$(aws_ec2_get_public_ip_for_instance_name "${name}")"
        aws_r53_add_host "${PRIVATE_HOSTED_ZONE}" "${hostname}" "${priv_ip}"
    fi
    if [ "${CLOUDWATCH_ENABLED}" == "true" ]; then    
        log_info "Configuring CloudWatch on '${name}' ..."
        local -r cloudwatch_output="$(aws_configure_cloudwatch ${pub_ip} ${name})"
    fi
    # Output the instance id for callers to pick up
    echo "${instance_id}"
}

# Gets the instance id for the given EC2 instance name. If the optional
# required state parameter is given then only instances in that state will be
# considered.
aws_ec2_get_id_for_instance_name()
{
    local instance_name="$1"
    local required_state="$2"
    # Establish session
    session_get
    # Get instance id
    log_debug "Getting instance id for '${instance_name}'..."
    # Use AWS CLI to describe the instance and get its id
    local instance_id=""
    if [ "${required_state}" == "" ] ; then
        instance_id="$(aws ec2 describe-instances \
            --filters \
                "Name=tag:Name,Values=${instance_name}*" \
            --query "Reservations[*].Instances[*].[InstanceId]" \
            --output=text)"
    else
        instance_id="$(aws ec2 describe-instances \
            --filters \
                "Name=tag:Name,Values=${instance_name}*" \
                "Name=instance-state-name,Values=${required_state}" \
            --query "Reservations[*].Instances[*].[InstanceId]" \
            --output=text)"
    fi
    if [ -z "${instance_id}" ] || [ "${instance_id}" == "None" ] ; then
        log_debug "Warning: No id found for instance '${instance_name}'."
    else
        log_debug "Got id '${instance_id}' for instance '${instance_name}'."
        echo "${instance_id}"
    fi
}

# Gets the attached volume ids for the given instance id.
aws_ec2_get_instance_attached_volumes()
{
    local -r instance_id="$1"
    # Establish session
    session_get
    # Get instance attached volumes
    log_debug "Getting attached volumes for '${instance_id}'..."
    # Use AWS CLI to describe the volumes attached to the given instance
    local -r attached_volumes="$(aws ec2 describe-volumes \
        --filter "Name=attachment.instance-id,Values=${instance_id}" \
        --query "Volumes[*].VolumeId" --output text)"
    echo "${attached_volumes}"
}

# Gets the current instance state for the given instance id.
aws_ec2_get_instance_state()
{
    local -r instance_id="$1"
    # Establish session
    session_get
    # Get instance state
    log_debug "Getting instance state for '${instance_id}'..."
    # Use AWS CLI to describe the instance and get its state
    local -r instance_state="$(aws ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query "Reservations[*].Instances[*].State.Name" \
        --output text)"
    echo "${instance_state}"
}

# Gets the private IP address for the given EC2 instance name. Only running
# instances will be considered, instances in other states will be ignored.
aws_ec2_get_private_ip_for_instance_name()
{
    local instance_name="$1"
    # Establish session
    session_get
    # Get the private IP for the instance
    log_debug "Getting private IP for '${instance_name}'..."
    # Use AWS CLI to describe the instance and get its private IP address
    local -r private_ip=$(aws ec2 describe-instances \
        --filters \
            "Name=tag:Name,Values=${instance_name}*" \
            "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].[PrivateIpAddress]" \
        --output=text)
    if [ -z "${private_ip}" ] || [ "${private_ip}" == "None" ] ; then
        log_warn "No private IP found for instance '${instance_name}'."
    else
        log_debug "Got private IP '${private_ip}' for instance '${instance_name}'."
        echo "${private_ip}"
    fi
}

# Gets the public IP address for the given EC2 instance name. Only running
# instances will be considered, instances in other states will be ignored.
aws_ec2_get_public_ip_for_instance_name()
{
    local instance_name="$1"
    # Establish session
    session_get
    # Get the public IP for the instance
    log_debug "Getting public IP for '${instance_name}'..."
    # Use AWS CLI to describe the instance and get its public IP address
    local -r public_ip=$(aws ec2 describe-instances \
        --filters \
            "Name=tag:Name,Values=${instance_name}*" \
            "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].[PublicIpAddress]" \
        --output=text)
    if [ -z "${public_ip}" ] || [ "${public_ip}" == "None" ] ; then
        log_warn "No public IP found for instance '${instance_name}'."
    else
        log_debug "Got public IP '${public_ip}' for instance '${instance_name}'."
        echo "${public_ip}"
    fi
}

# Gets the volume id for the given EC2 volume name.
aws_ec2_get_id_for_volume_name()
{
    local volume_name="$1"
    # Establish session
    session_get
    # Get the volume id
    log_debug "Getting volume id for '${volume_name}'..."
    # Use AWS CLI to describe the volume and get its id
    local -r volume_id=$(aws ec2 describe-volumes \
        --filters "Name=tag:Name,Values=${volume_name}*" \
        --query "Volumes[*].VolumeId" \
        --output=text)
    if [ -z "${volume_id}" ] || [ "${volume_id}" == "None" ] ; then
        log_warn "No id found for volume '${volume_name}'."
    else
        log_debug "Got id '${volume_id}' for volume '${volume_name}'."
        echo "${volume_id}"
    fi
}

# Gets the instance id(s) that the volume with the given id is attached to.
aws_ec2_get_volume_attached_instance_ids()
{
    local volume_id="$1"
    # Establish session
    session_get
    # Get attached instances for the volume
    log_debug "Getting volume attachments for '${volume_id}'..."
    # Use AWS CLI to describe the volume and get its attached instance ids
    local -r instance_ids="$(aws ec2 describe-volumes \
        --volume-id "${volume_id}" \
        --query "Volumes[0].Attachments[*].InstanceId" \
        --output text)"
    echo "${instance_ids}"
}

# Gets the current volume state for the given volume id.
aws_ec2_get_volume_state()
{
    local volume_id="$1"
    # Establish session
    session_get
    # Get the state of the volume
    log_info "Getting volume state for '${volume_id}'..."
    # Use AWS CLI to describe the volume and get its state
    local -r volume_state="$(aws ec2 describe-volumes \
        --volume-id "${volume_id}" \
        --query "Volumes[0].State" \
        --output text)"
    echo "${volume_state}"
}

# Tags the given resource with the given name, project id and environment.
aws_ec2_tag_resource()
{
    local -r resource_id="$1"
    local -r tag_name="$2"
    local -r tag_proj="$3"
    local -r tag_env="$4"
    # Establish session
    session_get
	# Tag the resource with the given tags
	log_debug "Tagging '${resource_id}': Name='${tag_name}', ProjectId='${tag_proj}', Environment='${tag_env}'..."
	aws ec2 create-tags \
		--resources "${resource_id}" \
		--tags \
		  "Key=Name,Value=${tag_name}" \
		  "Key=ProjectId,Value=${tag_proj}" \
		  "Key=Environment,Value=${tag_env}"
	log_info "Tagged '${resource_id}': Name='${tag_name}', ProjectId='${tag_proj}', Environment='${tag_env}'."
}

# Terminates the instance with the given id or ids. If multiple instance ids are
# given then all instances will be terminated.
aws_ec2_terminate_instance()
{
    local -r instance_id="$1"
    # Establish session
    session_get
    # Terminate instance
    log_info "Terminating instance '${instance_id}'..."
    aws ec2 terminate-instances --instance-ids "${instance_id}"
    # If we got an instance id (or ids) then iterate through them to confirm
    # they are or it is in a terminated state (multiple ids can happen if instances
    # are stopped/started in quick succession or if a AWS limit is hit).
    # shellcheck disable=SC2001
    for i_id in $(echo "${instance_id}" | sed "s/$/ /g") ; do
        local i_state
        i_state="$(aws_ec2_get_instance_state "${i_id}")"
        # Wait for the instance to shut down
        while [ "${i_state}" != "terminated" ] ; do
            log_info "Waiting for instance '${i_id}' to shut down (${i_state})"
            sleep 8
            i_state="$(aws_ec2_get_instance_state "${i_id}")"
        done
        log_info "Terminated instance '${instance_id}'."
    done
}

# Determines if a keypair with the given name exists. Returns true if it does,
# or false otherwise.
aws_keypair_exists()
{
    local -r keypair_name="$1"
    [ "$(aws ec2 describe-key-pairs --filter \
            "Name=key-name,Values=${keypair_name}" \
            --query "KeyPairs[*].KeyName" --output text)" != "" ]
    return $?
}

# Imports the given source key with the given key name. If a key with the same
# name already exists then it will be left as-is and not be replaced.
aws_keypair_import()
{
    local -r keypair_name="$1"
    local -r keypair_srcpath="$2"
    # Establish session
    session_get
    # Read the public key data
    local -r pub_key="$(openssl rsa -in "${keypair_srcpath}" \
        -pubout 2>/dev/null | tail -n +2 | head -n -1 | tr -d "\\n")"
    if ! aws_keypair_exists "${keypair_name}" ; then
        log_info "Importing keypair '${keypair_srcpath}' as '${keypair_name}' ..."
        aws ec2 import-key-pair \
            --key-name "${keypair_name}" \
            --public-key-material "${pub_key}"
        log_info "Imported keypair '${keypair_name}'."
    fi
}

# Removes the keypair with the given name, if it exists.
aws_keypair_remove()
{
    local -r keypair_name="$1"
    # Establish session
    session_get
    # Remove the keypair
    if aws_keypair_exists "${keypair_name}" ; then
        log_info "Deleting keypair '${keypair_name}' ... "
        aws ec2 delete-key-pair --key-name "${keypair_name}"
        log_info "Deleted keypair '${keypair_name}'."
    fi
}

# Adds the given host name and IP address to the DNS for the given zone.
aws_r53_add_host()
{
    local -r zone_name="$1"
    local -r host_name="$2"
    local -r host_ip="$3"
    # Establish session
    session_get
    # Get the zone id
    local -r zone_id="$(aws_r53_get_zone "${zone_name}")"
    if [ "${zone_id}" != "" ] ; then
        log_info "Updating host entry for '${host_name}' to '${host_ip}' for zone '${zone_name}' ..."
        # Create the change file
        local -r change_file="/tmp/r53_add_host.$(date +"%s").json"
        cat << EOF > "${change_file}"
{
    "Comment": "Update record to reflect new IP for ${host_name}",
    "Changes" : [
         {
             "Action": "UPSERT",
             "ResourceRecordSet": {
                 "Name": "${host_name}.${zone_name}",
                 "Type": "A",
                 "TTL": 60,
                 "ResourceRecords": [
                     {
                         "Value": "${host_ip}"
                     }
                 ]
             }
         }
    ]
}
EOF
        # Submit for processing
        local -r change_id="$(aws route53 change-resource-record-sets \
            --hosted-zone-id "${zone_id}" \
            --change-batch "file://${change_file}" \
            --query ChangeInfo.Id \
            --output text)"
        log_info "Host entry '${host_name}' update requested. ChangeId=${change_id##*/}"
        # Remove the temporary change file
        rm -f "${change_file}"
    else
        log_warn "Zone '${zone_name}' doesn't exist."
    fi
}

# Adds an alias for the given host name and target host to the DNS for the given
#zone.
aws_r53_add_host_alias()
{
    local -r zone_name="$1"
    local -r host_name="$2"
    local -r target_host="$3"
    # Get the zone id
    local -r zone_id="$(aws_r53_get_zone "${zone_name}")"
    if [ "${zone_id}" != "" ] ; then
        log_info "Updating host alias entry for '${host_name}' -> '${target_host}' for zone '${zone_name}' ..."
        # Create the change file
        local -r change_file="/tmp/r53_add_host_alias.$(date +"%s").json"
        cat << EOF > "${change_file}"
{
    "Comment": "Update record to reflect new alias for ${target_host}",
    "Changes" : [
         {
             "Action": "UPSERT",
             "ResourceRecordSet": {
                 "Name": "${host_name}.${zone_name}",
                 "Type": "CNAME",
                 "TTL": 3600,
                 "ResourceRecords": [
                     {
                         "Value": "${target_host}"
                     }
                 ]
             }
         }
    ]
}
EOF
        # Submit for processing
        local -r change_id="$(aws route53 change-resource-record-sets \
            --hosted-zone-id "${zone_id}" \
            --change-batch "file://${change_file}" \
            --query ChangeInfo.Id \
            --output text)"
        log_info "Host entry '${host_name}' update requested. ChangeId=${change_id##*/}"
        # Remove the temporary change file
        rm -f "${change_file}"
    else
        log_warn "Zone '${zone_name}' doesn't exist."
    fi
}

# Adds the given service name, port, protocol and FQHN to the DNS for the given zone.
aws_r53_add_service()
{
    local -r zone_name="$1"
    local -r srv_name="$2"
    local -r srv_port="$3"
    local -r srv_proto="$4"
    local -r srv_host="$5"
    # Get the zone id
    local -r zone_id="$(aws_r53_get_zone "${zone_name}")"
    if [ "${zone_id}" != "" ] ; then
        log_info "Updating service entry for '${srv_name}:${srv_port}/${srv_proto}' for zone '${zone_name}' ..."
        # Create the change file
        local -r change_file="/tmp/r53_add_service.$(date +"%s").json"
        cat << EOF > "${change_file}"
{
    "Comment": "Update record for ${srv_name}:${srv_port}/${srv_proto} -> ${srv_host}",
    "Changes" : [
         {
             "Action": "UPSERT",
             "ResourceRecordSet": {
                 "Name": "_${srv_name}._${srv_proto}.${zone_name}",
                 "Type": "SRV",
                 "TTL": 300,
                 "ResourceRecords": [
                     {
                         "Value": "0 100 ${srv_port} ${srv_host} "
                     }
                 ]
             }
         }
    ]
}
EOF
        # Submit for processing
        local -r change_id="$(aws route53 change-resource-record-sets \
            --hosted-zone-id "${zone_id}" \
            --change-batch "file://${change_file}" \
            --query ChangeInfo.Id \
            --output text)"
        log_info "Service entry '${srv_name}:${srv_port}/${srv_proto} -> ${srv_host}' update requested. ChangeId=${change_id##*/}"
        # Remove the temporary change file
        rm -f "${change_file}"
    else
        log_warn "Zone '${zone_name}' doesn't exist."
    fi
}

# Creates a new private zone for the given VPC and with the given name.
aws_r53_create_private_zone()
{
    local -r vpc_id="$1"
    if [ "${vpc_id}" == "" ] ; then
        return
    fi
    local -r zone_name="$2"
    if [ "${zone_name}" == "" ] ; then
        return
    fi
    local zone_id
    zone_id=$(aws_r53_get_zone "${zone_name}")
    if [ "${zone_id}" == "" ] ; then
        # Zone doesn't exist create it
        log_info "Creating private zone '${zone_name}' for VPC '${vpc_id}'..."
        local -r deploy_date="$(date --utc +"%F %TZ")"
        zone_id=$(aws route53 create-hosted-zone \
            --name "${zone_name}" \
            --vpc "VPCRegion=${AWS_REGION},VPCId=${vpc_id}" \
            --caller-reference "$(date --utc --rfc-3339=ns)" \
            --hosted-zone-config \
                "PrivateZone=true,Comment=Deployed ${deploy_date} for ${PROJECT_ID}-${ENVIRONMENT}" \
            --query "HostedZones[?Name=='${zone_name}.'].Id" \
            --output text)
        while [ "${zone_id}" == "None" ] ; do
            zone_id="$(aws_r53_get_zone "${zone_name}")"
            log_debug "Waiting for zone to become ready..."
            sleep 2
        done
        zone_id="${zone_id##*/}"
        # Tag the zone with the project id and environment
        aws route53 change-tags-for-resource \
            --resource-type hostedzone \
            --resource-id "${zone_id}" \
            --add-tags \
                "Key=Name,Value=${PROJECT_ID}-${ENVIRONMENT} Private Zone" \
                "Key=ProjectId,Value=${PROJECT_ID}" \
                "Key=Environment,Value=${ENVIRONMENT}"
        log_info "Created private zone '${zone_name}' for VPC '${vpc_id}' with id '${zone_id}'."
    else
        log_debug "Private zone '${zone_name}' already exists."
    fi
}

# Creates a new public zone with the given name.
aws_r53_create_public_zone()
{
    local -r zone_name="$1"
    if [ "${zone_name}" == "" ] ; then
        return
    fi
    local zone_id
    zone_id=$(aws_r53_get_zone "${zone_name}")
    if [ "${zone_id}" == "" ] ; then
        # Zone doesn't exist create it
        log_info "Creating public zone '${zone_name}' ..."
        local -r deploy_date="$(date --utc +"%F %TZ")"
        zone_id=$(aws route53 create-hosted-zone \
            --name "${zone_name}" \
            --caller-reference "$(date --utc --rfc-3339=ns)" \
            --hosted-zone-config \
                Comment="Deployed ${deploy_date} for ${PROJECT_ID}-${ENVIRONMENT}" \
            --query "HostedZones[?Name=='${zone_name}.'].Id" \
            --output text)
        while [ "${zone_id}" == "None" ] ; do
            zone_id="$(aws_r53_get_zone "${zone_name}")"
            log_debug "Waiting for zone to become ready..."
            sleep 2
        done
        zone_id="${zone_id##*/}"
        # Tag the zone with the project id and environment
        aws route53 change-tags-for-resource \
            --resource-type hostedzone \
            --resource-id "${zone_id}" \
            --add-tags \
                "Key=Name,Value=${PROJECT_ID}-${ENVIRONMENT} Public Zone" \
                "Key=ProjectId,Value=${PROJECT_ID}" \
                "Key=Environment,Value=${ENVIRONMENT}"
        log_info "Created public zone '${zone_name}' with id '${zone_id}'."
    else
        log_debug "Public zone '${zone_name}' already exists."
    fi
}

# Gets id for the zone with the given name, or nothing if it doesn't exist.
aws_r53_get_zone()
{
    local -r zone_name="$1"
    if [ "${zone_name}" == "" ] ; then
        return
    fi
    local -r zone_id=$(aws route53 list-hosted-zones \
        --query "HostedZones[?Name=='${zone_name}.'].Id" \
        --output text)
    echo "${zone_id##*/}"
}

# Gets the nameservers for the zone with the given name, or nothing if no such
# zone exists.
aws_r53_get_zone_ns()
{
    local -r zone_name="$1"
    if [ "${zone_name}" == "" ] ; then
        return
    fi
    local -r zone_id="$(aws_r53_get_zone "${zone_name}")"
    if [ "${zone_id}" != "" ] ; then
        local -r zone_ns="$(aws route53 get-hosted-zone \
            --id "${zone_id}" \
            --query DelegationSet.NameServers \
            --output text)"
        echo "${zone_ns}"
    fi
}

# Removes the zone with the given name, if it exists. This assumes that the zone
# has no resource records, i.e. it will only remove zones that are empty. The
# deleted zone will enter a PENDING state - this function returns the Change Id,
# but does not wait for the deletion to complete.
aws_r53_remove_zone()
{
    local -r zone_name="$1"
    local -r zone_id="$(aws_r53_get_zone "${zone_name}")"
    if [ "${zone_id}" != "" ] ; then
        # Remove the zone
        log_info "Requesting removal of zone '${zone_name}' ..."
        local -r change_id="$(aws route53 delete-hosted-zone \
            --id "${zone_id##*/}" \
            --query "ChangeInfo.Id" --output text)"
        log_info "Zone '${zone_name}' is being removed. ChangeId=${change_id##*/}."
    else
        log_debug "Zone '${zone_name}' doesn't exist."
    fi
}

aws_r53_remove_zone_records()
{
    local -r zone_name="$1"
    local -r zone_id="$(aws_r53_get_zone "${zone_name}")"
    if [ "${zone_id}" != "" ] ; then
        # Remove all the records for the zone, except NS and SOA
        log_info "Requesting removal of all records for zone '${zone_name}' ..."
        local change_id
        aws route53 list-resource-record-sets --hosted-zone-id "${zone_id}" |
            jq -c '.ResourceRecordSets[]' |
        while read -r r_recordset; do
            # shellcheck disable=SC2005
            # shellcheck disable=SC2046
            read -r name type <<<$(echo "$(jq -r '.Name,.Type' <<<"${r_recordset}")")
            if [ "${type}" != "NS" ] && [ "${type}" != "SOA" ]; then
                change_id="$(aws route53 change-resource-record-sets \
                    --hosted-zone-id "${zone_id}" \
                    --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":
                      '"${r_recordset}"'
                    }]}' \
                    --output text --query 'ChangeInfo.Id')"
                log_info "Record '${name}' is being removed. ChangeId=${change_id##*/}."
            fi
        done
    else
        log_debug "Zone '${zone_name}' doesn't exist."
    fi
}

# Gets the current AWS session or requests a new one if none existing.
aws_session_get()
{
    # See if we need to authenticate
    if [ ! -s "${MACHINE_CREDENTIALS_FILE}" ] ; then
        if [ "${MFA_AUTH_ENABLED}" == "true" ] ; then
            aws_auth_mfa
        else
            aws_auth
        fi
    fi
    # Set env var values based on credentials file
    export AWS_ACCESS_KEY_ID
    AWS_ACCESS_KEY_ID="$(cut "${MACHINE_CREDENTIALS_FILE}" -f2)"
    export AWS_SESSION_EXPIRY_DATE
    AWS_SESSION_EXPIRY_DATE="$(cut "${MACHINE_CREDENTIALS_FILE}" -f3)"
    export AWS_SECRET_ACCESS_KEY
    AWS_SECRET_ACCESS_KEY="$(cut "${MACHINE_CREDENTIALS_FILE}" -f4)"
    export AWS_SESSION_TOKEN
    AWS_SESSION_TOKEN="$(cut "${MACHINE_CREDENTIALS_FILE}" -f5)"
    log_debug "AccessKey       = ${AWS_ACCESS_KEY_ID}"
    log_debug "ExpiryDate      = ${AWS_SESSION_EXPIRY_DATE}"
    log_debug "SecretAccessKey = ${AWS_SECRET_ACCESS_KEY}"
    log_debug "SessionToken    = ${AWS_SESSION_TOKEN}"
    # Check if the credentials have expired and re-auth if they have
    local -r now=$(date --utc +"%s")
    local -r expiry=$(date --utc -d "${AWS_SESSION_EXPIRY_DATE}" +"%s")
    if [ "${now}" -ge "${expiry}" ] ; then
        log_info "Existing session expired, refreshing..."
        session_refresh
    fi
}

# Removes the current AWS session from the environment.
aws_session_rm()
{
    # Wipe the current AWS environment context
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_EXPIRY_DATE
    unset AWS_SESSION_TOKEN
}

# Adds an ingress rule for the given security group, protocol, port(s) and cidr.
# The 'port' parameter can either be a single port or a range, given as
# 'min-max', e.g. '0-1024'.
aws_sg_authorize_ingress()
{
    local -r sg_id="$1"
    local -r proto="$2"
    local -r port="$3"
    local -r cidr="$4"
    local -r port_from="$(echo "${port}" | cut -d- -f1)"
    local -r port_to="$(echo "${port}" | cut -d- -f2)"
    if [ "$(aws ec2 describe-security-groups \
            --filters \
                "Name=group-id,Values=${sg_id}" \
                "Name=ip-permission.protocol,Values=${proto}" \
                "Name=ip-permission.from-port,Values=${port_from}" \
                "Name=ip-permission.to-port,Values=${port_to}" \
                "Name=ip-permission.cidr,Values=${cidr}" \
            --query 'SecurityGroups[*].GroupId' \
            --output text)" == "" ] ; then
        # Create the ingress rule for the security group
        aws ec2 authorize-security-group-ingress \
            --group-id "${sg_id}" --protocol "${proto}" --port "${port}" \
            --cidr "${cidr}"
    fi
}

# Creates a new security group with the given name if it doesn't already exist.
aws_sg_create()
{
    local -r sg_name="$1"
    local sg_id
    sg_id="$(aws_sg_get "${sg_name}")"
    if [ "${sg_id}" == "" ] ; then
        # Create the security group ...
        sg_id="$(aws ec2 create-security-group \
            --group-name "${sg_name}" \
            --description "Security group for ${sg_name}" \
            --vpc-id "${VPC_ID}" \
            --query 'GroupId' \
            --output text)"
        # ... and tag it
        aws_ec2_tag_resource "${sg_id}" \
            "${sg_name}" "${PROJECT_ID}" "${ENVIRONMENT}"
    fi
    echo "${sg_id}"
}

# Forcibly removes the security group with the given name, waiting indefinitely
# for it to become unused before removing it. This will block if the security
# group cannot be removed.
aws_sg_destroy()
{
    local -r sg_name="$1"
    local -r sg_id="$(aws_sg_get "${sg_name}")"
    if [ "${sg_id}" != "" ] ; then
        # Check if the SG is explicitly in use, and wait until it's not
        while [ "$(aws_sg_in_use "${sg_name}")" == "true" ] ; do
            log_info "Waiting for security group '${sg_name}' to become unused..."
            sleep 8
        done
        # Even after EC2 instances have been terminated, SG can still error when
        # attempting to remove it. We therefore capture the stdout and handle these
        # errors
        log_info "Removing security group '${sg_name}'..."
        local status
        status="$(aws ec2 delete-security-group --group-id "${sg_id}" 2>&1)"
        local removed
        # Handle any errors whilst removing the SG
        until [ "$removed" == "true" ] ; do
            if [ "${status}" == "" ] ; then
                # No output means no error, SG has been removed
                log_info "Removed security group '${sg_name}'."
                removed="true"
            elif echo "${status}" | grep -q DependencyViolation ; then
                # DependencyViolation error - SG is still shown as in use
                log_info "Waiting for security group '${sg_name}' to become free..."
                sleep 4
                status="$(aws ec2 delete-security-group --group-id "${sg_id}" 2>&1)"
            else
                # Unhandled status message
                log_error "Unhandled status whilst removing security group '${sg_name}': ${status}"
                break
            fi
        done
    fi
}

# Gets the security group id for the given name, if one exists.
aws_sg_get()
{
    local sg_name="$1"
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${sg_name}" \
        --query "SecurityGroups[*].GroupId"\
        --output text
}

# Returns true if the security group with the given name is in use.
aws_sg_in_use()
{
    local -r sg_name="$1"
    local -r sg_id="$(aws_sg_get "${sg_name}")"
    if [ ! -z "${sg_id}" ] ; then
        # See if there are any EC2 instances using the group
        if [ "$(aws ec2 describe-instances --query \
           'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
           --output text \
           | grep "${sg_id}")" != "" ] ; then
            echo "true"
        # See if there are any EC2 network interfaces using the group
        elif [ "$(aws ec2 describe-network-interfaces \
           --filters "Name=group-id,Values=${sg_id}" \
           --query  'NetworkInterfaces[*].NetworkInterfaceId' \
           --output text)" != "" ] ; then
            echo "true"
        fi
    fi
}

# Removes the security group for the given name, if one exists.
aws_sg_remove()
{
    local -r sg_name="$1"
    local -r sg_id="$(aws_sg_get "${sg_name}")"
    if [ "${sg_id}" != "" ] ; then
        log_info "Removing security group '${sg_name}'..."
        aws ec2 delete-security-group --group-id "${sg_id}"
        log_info "Removed security group '${sg_name}'."
    fi
}

# Gets the CIDR for the VPC with the given id.
aws_vpc_get_cidr()
{
    local -r vpc_id="$1"
    aws ec2 describe-vpcs \
        --vpc-ids "${vpc_id}" \
        --query 'Vpcs[0].CidrBlock' \
        --output text
}

# Gets the id of the subnet with the given 'index' (as returned by the AWS API)
# for the given VPC.
aws_vpc_get_subnet()
{
    local -r vpc_id="$1"
    local -r subnet_index="$2"
    aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${vpc_id}" \
        --query "Subnets[${subnet_index}].SubnetId" \
        --output text
}

#Configure System log on the CloudWatch if enabled.
aws_configure_cloudwatch()
{
    local -r pub_ip="$1"
    local -r instance_name="$2"
    local -r ssh_check="ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o BatchMode=yes"
    local -r ssh_connect="ssh -t -i ${SSH_KEY_PATH} ec2-user@${pub_ip}"
    local -r awslog_conf_path="/etc/awslogs/awslogs.conf"
    local -r awscli_conf_path="/etc/awslogs/awscli.conf"
    local -r log_group_name="${PROJECT_ID}-${ENVIRONMENT}"
    # Probe SSH connection until it's avalable 
    X_READY=''
    while [ ! $X_READY ]; do
       sleep 10
       set +e
       OUT=$(${ssh_check} ec2-user@${pub_ip} 2>&1 | grep 'Permission denied' )
       [[ $? = 0 ]] && X_READY='ready'
       set -e
    done 
    sleep 10
    ${ssh_check} ec2-user@${pub_ip} 2>&1 | grep 'Permission denied'
    scp -i "${SSH_KEY_PATH}" etc/awscli.conf.aws ec2-user@"${pub_ip}":/tmp/awscli.conf
    scp -i "${SSH_KEY_PATH}" etc/awslogs.conf.aws ec2-user@"${pub_ip}":/tmp/awslogs.conf
    ${ssh_connect} \
    "sudo yum install -y awslogs && \
    sudo mv /tmp/aws*.conf /etc/awslogs/ && \
    sudo sed -i 's/hostname_template/${instance_name}/g' ${awslog_conf_path} && \
    sudo sed -i 's/log_group_template/"${log_group_name}"/g' ${awslog_conf_path} && \
    sudo sed -i 's/region_template/"${AWS_REGION}"/g' ${awscli_conf_path} && \
    sudo chkconfig awslogs on && \
    sudo service awslogs restart"
}
_LIB_AWS_SH="LOADED"
log_debug "Loaded lib-aws"
fi # END
