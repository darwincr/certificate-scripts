#!/bin/bash

# Script updates Authelia certchain and key. It also restarts
# the Authelia service.

# This script should be securely placed with limited access
# (e.g. owned by root with permissions of 700) to avoid
# compromising the API Keys

# ECDSA Keys ARE supported

## Recommended cron -- run at boot (in case system was powered off
# during a renewal, and run weekly)
# Pick any time you like. This time was arbitrarily selected.

# sudo crontab -e
# @reboot sleep 15 && /script/path/here
# 5 4 * * 2 /script/path/here

## Set VARs in accord with environment
cert_apikey=<cert API key>
key_apikey=<key API key>
# server hosting key/cert
server=certdp.local:port
# name of the key/cert (as it is on server)
cert_name=authelia.example.com

# URL paths
api_cert_path=certwarden/api/v1/download/certificates/$cert_name
api_key_path=certwarden/api/v1/download/privatekeys/$cert_name
# local user who will own certs (adjust if Authelia runs as different user)
cert_owner=root
# local cert storage
local_certs=/etc/authelia/certs
# path to store a timestamp to easily see when script last ran
time_stamp=/etc/authelia/certs/cert_timestamp.txt
# temp folder
temp_certs=/tmp/tempcerts

## Script
# stop / fail on any error
set -e

rm -rf $temp_certs
mkdir -p $temp_certs
mkdir -p $local_certs
# Fetch certs, if curl returns anything other than 200 success, abort
http_statuscode=$(curl -L https://$server/$api_cert_path -H "apiKey: $cert_apikey" --output $temp_certs/certchain.pem --write-out "%{http_code}")
if test $http_statuscode -ne 200; then exit "$http_statuscode"; fi
http_statuscode=$(curl -L https://$server/$api_key_path -H "apiKey: $key_apikey" --output $temp_certs/key.pem --write-out "%{http_code}")
if test $http_statuscode -ne 200; then exit "$http_statuscode"; fi

# if different
if ( ! cmp -s "$temp_certs/certchain.pem" "$local_certs/certchain.pem" ) || ( ! cmp -s "$temp_certs/key.pem" "$local_certs/key.pem" ) ; then
    systemctl stop authelia.service

    cp -rf $temp_certs/* $local_certs/

    chown $cert_owner:$cert_owner $local_certs/*
    chmod 600 $local_certs/key.pem
    chmod 644 $local_certs/certchain.pem

    systemctl start authelia.service
fi

rm -rf $temp_certs
echo "Last Run: $(date)" > $time_stamp
