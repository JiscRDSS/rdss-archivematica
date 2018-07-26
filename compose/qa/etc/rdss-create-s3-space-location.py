#!/usr/bin/env python

""This script aims to create a S3 space and its AIP Storage location in the
Archivematica storage service if they don't already exist.

It first lists the existing Spaces defined in the Storage Service via the
API. It checks if any of them is using the S3 protocol.

If this space doesn't exist, it creates the S3 space with the variables:

* S3_AIP_STORE_ACCESS_KEY_ID
* S3_AIP_STORE_ENDPOINT_URL
* S3_AIP_STORE_PATH
* S3_AIP_STORE_REGION
* S3_AIP_STORE_SECRET_ACCESS_KEY


At last, this script list the locations and check whether a locations with the
path "$S3_AIP_STORE_PATH/s3-aipstore" exists. To create this new locations, it
first obtains the resource URIs for the Pipeline and Space that the new
locations will be added to using the Storage Service API. It assumes that there
will only be one Pipeline and the default FS Space has the index #0, and the S3
space has the index #1, since this is what is expected in the RDSS deployment.

Having identified the URIs for the pipeline and space, it then uses the API to
create the required location.

It requires the non-standard 'requests' module to be installed:

`pip install requests`

"""


import argparse
import sys

# Check we have the required 'requests' module installed
import pkg_resources
try:
    pkg_resources.get_distribution('requests')
except pkg_resources.DistributionNotFound:
    print "Required module 'requests' not installed, aborting."
    sys.exit(1)

# We have the required modules, okay to continue

import requests

# Process arguments

parser = argparse.ArgumentParser(
                    description='Creates required Storage Service locations.')
parser.add_argument('--base-url', required=True,
                    help='Base URL of Storage Service API to use.')
parser.add_argument('--api-user', required=True,
                    help='Username to use when authenticating with the API.')
parser.add_argument('--api-key', required=True,
                    help='Key to use when authenticating with the API.')
parser.add_argument('--s3-access-key-id', required=True,
                    help='S3 Access key ID.')
parser.add_argument('--s3-secret-access-key', required=True,
                    help='S3 Secret Access Key.')
parser.add_argument('--s3-path', required=True,
                    help='S3 bucket PATH.')
parser.add_argument('--s3-region', required=True,
                    help='S3 Region.')
parser.add_argument('--s3-endpoint-url', required=True,
                    help='S3 Endpoint URL.')

args = parser.parse_args()

# Strip trailing '/' off base_url, if any
args.base_url = args.base_url.rstrip('/')

# Output parameters
print "Using base URL '%s'" % args.base_url
print "Using API user '%s'" % args.api_user
print "Using API key '%s'" % args.api_key
print "Using S3 access key id '%s'" % args.s3_access_key_id
print "Using S3 secret access key '%s'" % args.s3_secret_access_key
print "Using S3 path '%s'" % args.s3_path
print "Using S3 region '%s'" % args.s3_region
print "Using S3 endpoint URL '%s'" % args.s3_endpoint_url

# Iterate through all the existing spaces and determine if the "s3" space
# already exists.

s3_space_exists = False


r = requests.get(
    '%s/api/v2/space/' % args.base_url,
    headers={
        'Authorization': 'ApiKey %s:%s' % (
            args.api_user,
            args.api_key)
    }
)

for space in r.json()['objects']:
    if space['access_protocol'] == 'S3':
        s3_space_exists = True

if not s3_space_exists:
    # S3 space doesn't exist, create it
    r = requests.post(
        '%s/api/v2/space/' % args.base_url,
        headers={
            'Authorization': 'ApiKey %s:%s' % (
                args.api_user,
                args.api_key)},
        json={
            'access_key_id': args.s3_access_key_id,
            'access_protocol': "S3",
            'endpoint_url': args.s3_endpoint_url,
            'path': args.s3_path,
            'staging_path': args.s3_path,
            'region': args.s3_region,
            'secret_access_key': args.s3_secret_access_key,
            'size': ""
        }
    )
    if r.ok:
        print "S3 space created."
    else:
        print "%s %s" % (r.status_code, r.reason)
        print r.text
else:
    print "S3 space already exists."





# Iterate through all the existing locations and determine if the "S3 AIP
# Store" Transfer Source location already exist

s3_aip_store_exists = False

r = requests.get(
    '%s/api/v2/location/' % args.base_url,
    headers={
        'Authorization': 'ApiKey %s:%s' % (
            args.api_user,
            args.api_key)
    }
)

for loc in r.json()['objects']:
    if loc['path'] == '%s/s3-aipstore' % args.s3_path: 
        s3_aip_store_exists = True

if not s3_aip_store_exists:
    # Get the URI of the pipeline. In RDSS we only have one.
    pipeline_uri = requests.get(
            '%s/api/v2/pipeline/' % args.base_url,
            headers={
                'Authorization': 'ApiKey %s:%s' % (
                    args.api_user,
                    args.api_key),
                'Content-Type': 'application/json'
            }
        ).json()['objects'][0]['resource_uri']

    # Get the URI of the second space (S3). In RDSS we have two: FS and S3
    space_uri = requests.get(
            '%s/api/v2/space/' % args.base_url,
            headers={
                'Authorization': 'ApiKey %s:%s' % (
                    args.api_user,
                    args.api_key),
                'Content-Type': 'application/json'
            }
        ).json()['objects'][1]['resource_uri']

    # Location for S3 Aip store doesn't exist, create it
    r = requests.post(
        '%s/api/v2/location/' % args.base_url,
        headers={
            'Authorization': 'ApiKey %s:%s' % (
                args.api_user,
                args.api_key)},
        json={
            'pipeline': [pipeline_uri],
            'purpose': 'AS',
            'relative_path': 's3-aipstore',
            'description': 's3-aipstore',
            'space': space_uri
        }
    )
    if r.ok:
        print "Location for S3 AIP Store created."
    else:
        print "%s %s" % (r.status_code, r.reason)
        print r.text
else:
    print "Location for S3 AIP Store already exists."
