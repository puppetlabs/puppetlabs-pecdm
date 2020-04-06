#!/usr/bin/env python3

# Example code copied from https://stackoverflow.com/a/48389364

# exports AWS environment variables for a given profile

import boto3
import argparse

parser = argparse.ArgumentParser(prog="exportaws",
    description="Extract AWS credentials for a profile as env variables.")
parser.add_argument("profile", help="profile name in ~/.aws/config.")
args = parser.parse_args()
creds = boto3.session.Session(profile_name=args.profile).get_credentials()
print(f'export AWS_ACCESS_KEY={creds.access_key}')
print(f'export AWS_SECRET_ACCESS_KEY={creds.secret_key}')
print(f'export AWS_SESSION_TOKEN={creds.token}')