# Export profile

If you are using MFA this sample script helps you to set the necessary environment variables

## Steps

### Requirements

### Requirements

* JQ
    * `jq` is a command-line tool for parsing JSON
    * If you are on MacOS you can install `jq` via Homebrew:

    ```
    brew install jq
    ```
    * [Here you will find more information to download](https://stedolan.github.io/jq/download/) `jq` for your OS

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

