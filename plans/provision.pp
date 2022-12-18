# @summary Provision infrastructure and deploy Puppet Enterprise in the cloud
#
# @param architecture
#   Which of the three supported architectures to provision infrastructure for
#
# @param cluster_profile
#   The profile of the cluster provisioned that determines if it is more suited
#   for development or production
#
# @param download_mode
#   The method peadm will use to transfer the PE installer to each
#   infrastructure node
#
# @param version
#   Which PE version to install with peadm
#
# @param compiler_count
#   Quantity of compilers that are provisioned and deployed in Large and Extra
#   Large installations
#
# @param ssh_pub_key_file
#   Path to the ssh public key file that will be passed to Terraform for
#   granting access to instances over SSH
#
# @param console_password
#   Initial admin user console password, if not provided you will be prompted to
#   input one or accept an insecure default
#
# @param node_count
#   Number of agent nodes to provision and enroll into deployment for testing
#   and development
#
# @param instance_image
#   The cloud image that is used for new instance provisioning, format differs
#   depending on provider
#
# @param windows_node_count
#   Number of Windows agent nodes to provision and enroll into deployment for testing
#   and development
#
# @param windows_instance_image
#   The cloud image that is used for new Windows instance provisioning, format differs
#   depending on provider
#
# @param windows_user
#   The adminstrative user account created on Windows nodes nodes allowing for WINRM connections
#
# @param windows_password
#   The adminstrative user account password on Windows nodes nodes allowing for WINRM connections
#
# @param subnet
#   Name or ID of an existing subnet to attach newly provisioned infrastructure
#   to
#
# @param subnet_project
#   If using the GCP provider, the name of the project which owns the existing
#   subnet you are attaching new infrastructure to if it is different than the
#   project you are provisioning into
#
# @param disable_lb
#   Option to disable load balancer creation for situations where you're
#   required to leverage alternate technology than what is provided by the cloud
#   provider
#
# @param ssh_ip_mode
#   The type of IPv4 address that will be used to gain SSH access to instances
#
# @param lb_ip_mode
#   The type of IPv4 address that is used for load balancing, private or public
#
# @param firewall_allow
#   IPv4 address subnets that should have access to PE through firewall
#
# @param dns_alt_names
#   Any additional DNS Alternative Names that must be assigned to PE
#   infrastructure node certificates
#
# @param extra_peadm_params
#   The pecdm plan does not expose all parameters available to peadm, if others
#   are needed then pass a hash
#
# @param extra_terraform_vars
#   The pecdm plan does not expose all variables defined by supporting Terraform
#   modules, if others are needed then pass a hash
#
# @param replica
#   Set to true to deploy a replica and enable PE DR for any of the three
#   supported architectures
#
# @param stage
#   Set to true if you want to skip PE deployment and just provision
#   infrastructure
#
# @param write_inventory
#   Optionally write an inventory.yaml to the current working directory which is
#   specific to the provider
#
# @param provider
#   Which cloud provider that infrastructure will be provisioned into
#
# @param project
#   One of three things depending on the provider used: a GCP project to deploy
#   infrastructure into, the name of the Azure resource group that is created
#   specifically for new infrastructure, or a simple tag attached to AWS
#   instances
#
# @param ssh_user
#   User name that will be used for accessing infrastructure over SSH, defaults
#   to ec2-user on when using the AWS provider but a value is required on GCp and Azure
#
# @param cloud_region
#   Which region to provision infrastructure in, if not provided default will
#   be determined by provider
#
# @param native_ssh
#   Set this to true if the plan should leverage native SSH instead of Ruby's
#   net-ssh library
#
plan pecdm::provision(
  Enum['xlarge', 'large', 'standard']           $architecture           = 'standard',
  Enum['development', 'production', 'user']     $cluster_profile        = 'development',
  Enum['direct', 'bolthost']                    $download_mode          = 'direct',
  String[1]                                     $version                = '2019.8.10',
  Integer                                       $compiler_count         = 1,
  Optional[String[1]]                           $ssh_pub_key_file       = undef,
  Optional[String[1]]                           $console_password       = undef,
  Optional[Integer]                             $node_count             = undef,
  Optional[Variant[String[1],Hash]]             $instance_image         = undef,
  Optional[Integer]                             $windows_node_count     = undef,
  Optional[Variant[String[1],Hash]]             $windows_instance_image = undef,
  Optional[String[1]]                           $windows_password       = undef,
  Optional[String[1]]                           $windows_user           = undef,
  Optional[Variant[String[1],Array[String[1]]]] $subnet                 = undef,
  Optional[String[1]]                           $subnet_project         = undef,
  Optional[Boolean]                             $disable_lb             = undef,
  Enum['private', 'public']                     $ssh_ip_mode            = 'public',
  Enum['private', 'public']                     $lb_ip_mode             = 'private',
  Array                                         $firewall_allow         = [],
  Array                                         $dns_alt_names          = [],
  Hash                                          $extra_peadm_params     = {},
  Hash                                          $extra_terraform_vars   = {},
  Boolean                                       $replica                = false,
  Boolean                                       $stage                  = false,
  Boolean                                       $write_inventory        = true,
  Boolean                                       $native_ssh             = pecdm::is_windows(),
  # The final three parameters depend on the value of $provider, to do magic
  Enum['google', 'aws', 'azure']                $provider,
  Optional[String[1]]                           $project                = undef,
  Optional[String[1]]                           $ssh_user               = undef,
  Optional[String[1]]                           $cloud_region           = undef
) {
  if $node_count and $lb_ip_mode != 'private' {
    fail_plan('The provisioning of agent nodes requires lb_ip_mode to be set to private')
  }

  if $console_password {
    $_console_password = $console_password
  } else {
    $_console_password = prompt('Input Puppet Enterprise console password now or accept default. [puppetlabs]',
      'sensitive' => true, 'default' => 'puppetlabs'
    )
  }

  if $windows_node_count {
    if $windows_password {
      $_windows_password = Sensitive($windows_password)
    } else {
      $_windows_password = prompt('Input Windows Node password or accept default. [Pupp3tL@b5P0rtl@nd!]',
        'sensitive' => true, 'default' => 'Pupp3tL@b5P0rtl@nd!'
      )
    }
  } else {
    $_windows_password = undef # prevents unknown variable errors when not provisioning Windows Agents
    if $windows_password {
      out::message('Windows node password reset to undef because no Windows Agents are to be provisioned')
    }
  }

  $provisioned = run_plan('pecdm::subplans::provision', {
    architecture           => $architecture,
    cluster_profile        => $cluster_profile,
    compiler_count         => $compiler_count,
    ssh_pub_key_file       => $ssh_pub_key_file,
    node_count             => $node_count,
    instance_image         => $instance_image,
    windows_node_count     => $windows_node_count,
    windows_instance_image => $windows_instance_image,
    subnet                 => $subnet,
    subnet_project         => $subnet_project,
    disable_lb             => $disable_lb,
    ssh_ip_mode            => $ssh_ip_mode,
    lb_ip_mode             => $lb_ip_mode,
    firewall_allow         => $firewall_allow,
    replica                => $replica,
    provider               => $provider,
    project                => $project,
    ssh_user               => $ssh_user,
    windows_user           => $windows_user,
    windows_password       => $_windows_password,
    cloud_region           => $cloud_region,
    native_ssh             => $native_ssh,
    extra_terraform_vars   => $extra_terraform_vars
  })

  # So the results can be seen in verbose mode if $stage is set
  out::verbose("pecdm::provision provisioned:\n\n${provisioned.to_json_pretty}\n")

  unless $stage {
    run_plan('pecdm::subplans::deploy', {
      inventory              => $provisioned['pe_inventory'],
      compiler_pool_address  => $provisioned['compiler_pool_address'],
      download_mode          => $download_mode,
      version                => $version,
      console_password       => $_console_password.unwrap,
      dns_alt_names          => $dns_alt_names,
      extra_peadm_params     => $extra_peadm_params
    })

    if $node_count {
      $agent_targets = get_targets(getvar('provisioned.agent_inventory').map |$target| {
        $target['name']
      }.flatten())
    }
    if $windows_node_count {
      $windows_agent_targets = get_targets(getvar('provisioned.windows_agent_inventory').map |$target| {
        $target['name']
      }.flatten())
    }
    if $node_count or $windows_node_count {
      run_plan('pecdm::utils::deploy_agents', $agent_targets + $windows_agent_targets, {
        primary_host          => getvar('provisioned.pe_inventory.server.0.name'),
        compiler_pool_address => $provisioned['compiler_pool_address'],
      })
    }
  } else {
    out::message('The parameter stage was set to true, infrastructure has been staged but Puppet Enterprise deployment skipped')
  }

  if $write_inventory {
    run_plan('pecdm::utils::inventory_yaml', {
      provider    => $provider,
      ssh_ip_mode => $ssh_ip_mode,
      native_ssh  => $native_ssh,
    })
  }
}
