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

This Bolt project demonstrates how you can link together automation tools to take advantage of their strengths, e.g. Terraform for infrastructure deployment and Puppet for infrastructure configuration. We take [puppetlabs/peadm](https://github.com/puppetlabs/puppetlabs-peadm) and some [Terraform manifests](Boltdir/ext/terraform) for GCP to facilitate rapid and repeatable deployments of Puppet Enterprise built upon the XL architecture, including fail over replica.

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

The command line will likely serve most uses of **autope** but if you wish to pass a longer list of IP blocks that are authorized to access your PE stack than creating a **params.json** file is going to be a good idea, instead of trying to type out a multi value array on the command line. The default value for **firewall_allow** is the internal network, if you pass a value other than `0.0.0.0/0` then make sure you include that IP block (`10.128.0.0/9`) or your instances will not be able to communicate as expected. Single IP addresses must be passed as a `/32`.

```
{
    "gcp_project"    : "example",
    "ssh_user"       : "john.doe",
    "version"        : "2019.0.4",
    "firewall_allow" : [ "10.128.0.0/9", "71.236.165.233/32",
                         "131.252.0.0/16", 140.211.0.0/16 ]

}
```

How to execute plan with **params.json**: `bolt plan run autope --params @params.json`

### Example: destroy stack

The only option still required when destroying what was built is **gcp_project**

`bolt plan run autope::destroy gcp_project=example`

## Limitations

Only supports what peadm supports, in addition only GCP, for now...
