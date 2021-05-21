# autope

Automatic Puppet Enterprise, a Bolt driven fusion of [puppetlabs/peadm](https://github.com/puppetlabs/puppetlabs-peadm) and Terraform.

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with autope](#setup)
    * [What autope affects](#what-autope-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with autope](#beginning-with-autope)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

The autope Bolt project demonstrates how you can link together automation tools to take advantage of their strengths, e.g. Terraform for infrastructure provisioning and Puppet for infrastructure configuration. We take [puppetlabs/peadm](https://github.com/puppetlabs/puppetlabs-peadm) and a Terraform module ([GCP](https://github.com/puppetlabs/terraform-google-pe_arch), [AWS](https://github.com/puppetlabs/terraform-aws-pe_arch)) to facilitate rapid and repeatable deployments of Puppet Enterprise built upon the Standard, Large or Extra Large architecture w/ optional fail over replica.

## Expectations and support

The autope Bolt project is developed by Puppet's Solutions Architecture team, intended as an internal tool to make the deployment of disposable stacks of Puppet Enterprise easy to deploy for the reproduction of customer issues, internal development, and demonstrations. Independent use is not recommended for production environments but with a comprehensive understanding of how Puppet Enterprise, Puppet Bolt, and Terraform work, plus high levels of comfort with the modification and maintenance of Terraform code and the infrastructure requirements of a full Puppet Enterprise deployment it could be referenced as an example for building your own automated solution.

The autope Bolt project is an internal tool, and is **NOT** supported through Puppet Enterprise's standard or premium support.puppet.com service.

If you are a Puppet Enterprise customer and come upon this project and wish to provide feedback, submit a feature request, or bugfix then please do so through the [Issues](https://github.com/puppetlabs/puppetlabs-autope/issues) and [Pull Request](https://github.com/puppetlabs/puppetlabs-autope/pulls) components of the GitHub project.

The project is under active development and yet to release an initial version. There is no guarantee yet on a stable interface from commit to commit and those commits may include breaking changes.

## Setup

### What autope affects

Types of things you'll be paying your cloud provider for

* Instances of various sizes
* Load balancers
* Networks

### Setup Requirements

#### Deploying upon GCP
* [GCP Cloud SDK Intalled](https://cloud.google.com/sdk/docs/quickstarts)
* [GCP Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default/)

#### Deploying upon AWS
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
* [Environment variables or Shared Credentials file Authentication Method](https://www.terraform.io/docs/providers/aws/index.html#authentication)
* [If using MFA, a script to set environment variables](examples/export-profile.py)

#### Common Requirements
* [Bolt Installed](https://puppet.com/docs/bolt/latest/bolt_installing.html)
* [Git Installed](https://git-scm.com/downloads)
* [Terraform Installed](https://www.terraform.io/downloads.html)

### Beginning with autope

1. Clone this repository: `git clone https://github.com/puppetlabs/puppetlabs-autope.git && cd puppetlabs-autope`
2. Install module dependencies: `bolt module install --no-resolve` (manually manages modules to take advantage of functionality that allows for additional content to be deployed that does not adhere to the Puppet Module packaging format, e.g. Terraform modules)
3. Run plan: `bolt plan run autope project=example ssh_user=john.doe firewall_allow='[ "0.0.0.0/0" ]'`
4. Wait. This is best executed from a bastion host or alternatively, a fast connection with strong upload bandwidth

## Usage

### Parameter requirments

Due to the creation of a elb load balancer (32 characters name limit) the project name can't be longer than 9 characters

### Example: params.json

The command line will likely serve most uses of **autope** but if you wish to pass a longer list of IP blocks that are authorized to access your PE stack than creating a **params.json** file is going to be a good idea, instead of trying to type out a multi value array on the command line. The value that will ultimately be set for the GCP firewall will always include the internal network address space to ensure everything works no matter what is passed in by the user.

```
{
    "project"        : "example",
    "ssh_user"       : "john.doe",
    "version"        : "2019.0.4",
    "provider"       : "google',
    "firewall_allow" : [ "71.236.165.233/32", "131.252.0.0/16", 140.211.0.0/16 ]

}
```

How to execute plan with **params.json**: `bolt plan run autope --params @params.json`

### Example: deploy standard architecture on AWS with the developer role using a MFA enabled user

This can also be used to deploy PE's large architecture without a fail over replica on AWS

```
$(export-profile.py development)
bolt plan run autope provider=aws architecture=standard
```

Please note that for bolt to authenticate to the AWS-provisioned VMs you need to enable ssh agent like so:

```bash
$ eval `ssh-agent`
$ ssh-add
```

### Example: destroy GCP stack

The number of options required are reduced when destroying a stack

`bolt plan run autope::destroy provider=google`

### Example: destroy AWS stack

The number of options required are reduced when destroying a stack

`bolt plan run autope::destroy provider=aws`

## Limitations

Only supports what peadm supports and AWS does not currently have parity with the GCP provider, e.g. AWS ignores a few parameters