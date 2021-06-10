# Assuming roles

In some organizations, your access to a cloud provider such as AWS (in this particular case) is done via bastion accounts or roles.

This guide will help you set the config and credentials files in your machine to assume a role via a bash script. This sample script helps you authenticate, switch roles, and set the necessary environment variables.

## Steps

### Requirements

* [AWS CLI](https://aws.amazon.com/cli/)
* JQ
    * `jq` is a command-line tool for parsing JSON
    * If you are on MacOS you can install it via Homebrew:

    ```
    brew install jq
    ```

    * [Here you will find more information to download](https://stedolan.github.io/jq/download/) `jq` for your OS

## AWS Config & Credentials

Make sure to set your AWS account credentials under `~/.aws/credentials`. This script also expects you have added a profile on `~/.aws/config`

It's worth noticing that you need to have [MFA enabled in your AWS account](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html) in order to assume roles.

### ~/.aws/credentials

You can create new API access keys in the AWS IAM service.

```
[default]
aws_access_key_id = <insert-your-access-key-here>
aws_secret_access_key = <insert-your-secret-key-here>
```

### ~/.aws/config

Add the details of your profile

```
[default]
region = eu-central-1

[profile my-custom-profile]
role_arn = arn:aws:iam::<account-id>:role/<role-name>
source_profile = default
mfa_serial = arn:aws:iam::<id>:mfa/<user-name>
```

### Setting the ENV vars

To generate the environment variables (`AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN`) run the `aws_bastion_mfa_export.sh` bash script, this will ask you to enter a MFA code

```
source aws_bastion_mfa_export.sh -p <profile-name>
```

**Response**

```
|_ Using profile flag: <profile-name>
|_ Requesting identity with profile <profile-name>
Enter MFA code for arn:aws:iam::<org-id>:mfa/<user-name>:
{
    "UserId": "...",
    "Account": "...",
    "Arn": "..."
}
exporting AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
|_ Current token expires at: 2021-06-08T15:34:18+00:00
```

