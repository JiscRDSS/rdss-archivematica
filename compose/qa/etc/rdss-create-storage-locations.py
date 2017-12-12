#!/usr/bin/env python

"""This script aims to create two Transfer Storage locations in the
Archivematica storage service if they don't already exist. These relate to the
"automated workflow" and the "interactive workflow" that are used in the RDSS
deployment.

It first lists the existing Locations defined in the Storage Service via the
API. It checks to see if any of them have the same path as the two locations we
wish to add - `/home/automated` and `/home/interactive`.

If either of the two locations do not exist, it creates them. It first obtains
the resource URIs for the Pipeline and Space that the new locations will be
added to using the Storage Service API. It assumes that there will only be one
Pipeline and Space, since this is what is expected in the RDSS deployment.

Having identified the URIs for the pipeline and space, it then uses the API to
create the required locations.

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
args = parser.parse_args()

# Strip trailing '/' off base_url, if any
args.base_url = args.base_url.rstrip('/')

# Output parameters
print "Using base URL '%s'" % args.base_url
print "Using API user '%s'" % args.api_user
print "Using API key '%s'" % args.api_key

# Iterate through all the existing locations and determine if the "automated"
# and "interactive" Transfer Source locations already exist

automated_exists = False
interactive_exists = False

r = requests.get(
    '%s/api/v2/location/' % args.base_url,
    headers={
        'Authorization': 'ApiKey %s:%s' % (
            args.api_user,
            args.api_key)
    }
)

for loc in r.json()['objects']:
    if loc['path'] == '/home/automated':
        automated_exists = True
    if loc['path'] == '/home/interactive':
        interactive_exists = True

if not automated_exists or not interactive_exists:
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

    # Get the URI of the space. In RDSS we only have one.
    space_uri = requests.get(
            '%s/api/v2/space/' % args.base_url,
            headers={
                'Authorization': 'ApiKey %s:%s' % (
                    args.api_user,
                    args.api_key),
                'Content-Type': 'application/json'
            }
        ).json()['objects'][0]['resource_uri']

    if not automated_exists:
        # Location for automated workflow doesn't exist, create it
        r = requests.post(
            '%s/api/v2/location/' % args.base_url,
            headers={
                'Authorization': 'ApiKey %s:%s' % (
                    args.api_user,
                    args.api_key)},
            json={
                'pipeline': [pipeline_uri],
                'purpose': 'TS',
                'relative_path': 'home/automated',
                'description': 'automated workflow',
                'space': space_uri
            }
        )
        if r.ok:
            print "Location for automated workflow created."
        else:
            print "%s %s" % (r.status_code, r.reason)
            print r.text
    else:
        print "Location for automated workflow already exists."

    if not interactive_exists:
        # Location for interactive workflow doesn't exist, create it
        r = requests.post(
            '%s/api/v2/location/' % args.base_url,
            headers={
                'Authorization': 'ApiKey %s:%s' % (
                    args.api_user,
                    args.api_key)},
            json={
                'pipeline': [pipeline_uri],
                'purpose': 'TS',
                'relative_path': 'home/interactive',
                'description': 'interactive workflow',
                'space': space_uri
            }
        )
        if r.ok:
            print "Location for interactive workflow created."
        else:
            print "%s %s" % (r.status_code, r.reason)
            print r.text
    else:
        print "Location for interactive workflow already exists."

else:
    print "Locations for automated and interactive workflows already exist."
