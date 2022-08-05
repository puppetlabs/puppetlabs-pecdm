# @summary Provision new PE cluster to The Cloud
#
plan pecdm::provision(
  Enum['xlarge', 'large', 'standard']           $architecture         = 'standard',
  Enum['development', 'production', 'user']     $cluster_profile      = 'development',
  Enum['direct', 'bolthost']                    $download_mode        = 'direct',
  String[1]                                     $version              = '2019.8.10',
  Integer                                       $compiler_count       = 1,
  Optional[String[1]]                           $ssh_pub_key_file     = undef,
  Optional[String[1]]                           $console_password     = undef,
  Optional[Integer]                             $node_count           = undef,
  Optional[Variant[String[1],Hash]]             $instance_image       = undef,
  Optional[Variant[String[1],Array[String[1]]]] $subnet               = undef,
  Optional[String[1]]                           $subnet_project       = undef,
  Optional[Boolean]                             $disable_lb           = undef,
  Enum['private', 'public']                     $ssh_ip_mode          = 'public',
  Enum['private', 'public']                     $lb_ip_mode           = 'private',
  Array                                         $firewall_allow       = [],
  Array                                         $dns_alt_names        = [],
  Hash                                          $extra_peadm_params   = {},
  Hash                                          $extra_terraform_vars = {},
  Boolean                                       $replica              = false,
  Boolean                                       $stage                = false,
  Boolean                                       $write_inventory      = false,
  # The final three parameters depend on the value of $provider, to do magic
  Enum['google', 'aws', 'azure']                $provider,
  Optional[String[1]]                           $project              = undef,
  Optional[String[1]]                           $ssh_user             = undef,
  Optional[String[1]]                           $cloud_region         = undef
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

  $provisioned = run_plan('pecdm::subplans::provision', {
    architecture         => $architecture,
    cluster_profile      => $cluster_profile,
    compiler_count       => $compiler_count,
    ssh_pub_key_file     => $ssh_pub_key_file,
    node_count           => $node_count,
    instance_image       => $instance_image,
    subnet               => $subnet,
    subnet_project       => $subnet_project,
    disable_lb           => $disable_lb,
    ssh_ip_mode          => $ssh_ip_mode,
    lb_ip_mode           => $lb_ip_mode,
    firewall_allow       => $firewall_allow,
    replica              => $replica,
    provider             => $provider,
    project              => $project,
    ssh_user             => $ssh_user,
    cloud_region         => $cloud_region,
    extra_terraform_vars => $extra_terraform_vars
  })

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

      run_plan('pecdm::utils::deploy_agents', $agent_targets, {
        primary_host          => getvar('provisioned.pe_inventory.server.0.name'),
        compiler_pool_address => $provisioned['compiler_pool_address'],
      })
    }
  } else {
    out::message('The parameter stage was set to true, infrastructure has been staged but Puppet Enterprise deployment skipped')
  }

  if $write_inventory {
    run_plan('pecdm::utils::inventory_yaml', {
      provider       => $provider,
      ssh_ip_mode    => $ssh_ip_mode,
      windows_runner => pecdm::is_windows()
    })
  }
}
