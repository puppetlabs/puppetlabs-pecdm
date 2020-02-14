# autope

Automatic PE, a Bolt driven fusion of [puppetlabs/peadm](https://github.com/puppetlabs/puppetlabs-peadm) and Terraform.

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

This Bolt project demonstrates how you can link together automation tools to take advantage of their strengths, e.g. Terraform for infrastructure deployment and Puppet for infrastructure configuration. We take [puppetlabs/peadm](https://github.com/puppetlabs/puppetlabs-peadm) and some [Terraform manifests](https://github.com/puppetlabs/terraform-pe_arch) for GCP to facilitate rapid and repeatable deployments of Puppet Enterprise built upon the Large or Extra Large architecture w/ fail over replica (default).

## Setup

### What autope affects

Types of things you'll be paying your cloud provider for

* Instances of various sizes
* Load balancers
* Networks

### Setup Requirements

* [GCP Cloud SDK Intalled](https://cloud.google.com/sdk/docs/quickstarts)
* [GCP Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default/)
* [Bolt Installed](https://puppet.com/docs/bolt/latest/bolt_installing.html)
* [Git Installed](https://git-scm.com/downloads)
* [Terraform Installed](https://www.terraform.io/downloads.html)

### Beginning with autope

1. Clone this repository: `git clone https://github.com/puppetlabs/puppetlabs-autope.git && cd puppetlabs-autope/Boltdir`
2. Install module dependencies: `bolt puppetfile install`
3. Run plan: `bolt plan run autope gcp_project=example ssh_user=john.doe firewall_allow='[ "0.0.0.0/0" ]'`
4. Wait. This is best executed from a GCP bastion host or alternatively, a fast connection with strong upload bandwidth

## Usage

### Example: params.json

The command line will likely serve most uses of **autope** but if you wish to pass a longer list of IP blocks that are authorized to access your PE stack than creating a **params.json** file is going to be a good idea, instead of trying to type out a multi value array on the command line. The value that will ultimately be set for the GCP firewall will always include the internal network address space to ensure everything works no matter what is passed in by the user. Single IP addresses must be passed as a `/32`.

```
{
    "gcp_project"    : "example",
    "ssh_user"       : "john.doe",
    "version"        : "2019.0.4",
    "firewall_allow" : [ "71.236.165.233/32", "131.252.0.0/16", 140.211.0.0/16 ]

}
```

How to execute plan with **params.json**: `bolt plan run autope --params @params.json`

### Example: deploy large architecture

This can also be used to deploy PE's large architecture without a fail over replica

`bolt plan run autope gcp_project=example ssh_user=john.doe firewall_allow='[ "0.0.0.0/0" ]' architecture=large`

### Example: destroy stack

The number of options required are reduced when destroying a stack

`bolt plan run autope::destroy`

## Limitations

Only supports what peadm supports, in addition only GCP, for now...
