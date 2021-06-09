#!/bin/bash

if [ "$#" -eq 0 ]; then
    printf 'no argument flags provided\n' >&2
    exit 1
fi

while getopts ":p:" flag; do
    case "$flag" in
        p ) profile=${OPTARG};;
        \? ) echo "Invalid option -$OPTARG" 1>&2; exit 1;;
        : ) echo "Invalid option -$OPTARG requires argument" 1>&2; exit 1;;
    esac
done

echo "|_ Using profile flag: $profile";

# Make sure we have a temporary token
# This will also request your MFA token if needed
echo "|_ Requesting identity with profile $profile"
aws sts get-caller-identity --profile $profile

cachedir=~/.aws/cli/cache
creds_json=$(cat $cachedir/*json)

AWS_ACCESS_KEY_ID=$(echo "$creds_json" | jq -r .Credentials.AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo "$creds_json" | jq -r .Credentials.SecretAccessKey)
AWS_SESSION_TOKEN=$(echo "$creds_json"  | jq -r .Credentials.SessionToken)

echo exporting AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

exp=$(echo "$creds_json" | jq -r .Credentials.Expiration)
echo "|_ Current token expires at: $exp"
