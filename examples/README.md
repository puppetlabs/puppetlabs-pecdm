# Export profile

If you are using MFA this sample script helps you to set the necessary environment variables

## Steps

Make sure to install the required Python modules via `pip` ([boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/quickstart.html#installation) and [argpase](https://pypi.org/project/argparse/))

To generate the environment variables run the `export-profile.py `python script, this will ask you to enter a MFA code:

```
$ python3 export-profile.py <custom-profile-here>

Enter MFA code for arn:aws:iam::<demo-org>:mfa/<demo-user>: 
```

The script will print to screen the lines you have to copy/paste to the terminal to set the environment variables:

```
export AWS_ACCESS_KEY=<...>
export AWS_SECRET_ACCESS_KEY=<...>
export AWS_SESSION_TOKEN=<...>
```

Now copy/paste the three lines from above and you will be set.


