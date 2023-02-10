# @summary Upgrade a pecdm provisioned cluster
#
plan pecdm::upgrade(
  Peadm::Pe_version                        $version            = '2021.7.2',
  Boolean                                  $native_ssh         = false,
  Enum['private', 'public']                $ssh_ip_mode        = 'public',
  Optional[Enum['google', 'aws', 'azure']] $provider           = undef,
  Hash                                     $extra_peadm_params = {},
  String[1]                                $ssh_user           = $provider ? { 'aws' => 'ec2-user', default => undef },
) {
  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local' })

  if $provider {
    $_provider = $provider
    $tf_dir = ".terraform/${_provider}_pe_arch"
  } else {
    $detected_provider = ['google', 'aws', 'azure'].map |String $provider| {
      $tf_dir = ".terraform/${provider}_pe_arch"
      $terraform_output = run_task('terraform::output', 'localhost', dir => $tf_dir).first
      unless $terraform_output.value.empty {
        $provider
      }
    }.peadm::flatten_compact()

    if $detected_provider.length > 1 {
      fail_plan("Provider detection found two active providers, ${detected_provider.join(', ')}; to use the pecdm::upgrade plan, pass the ${provider} parameter to explicitly select one")
    }

    $_provider = $detected_provider[0]
    $tf_dir = ".terraform/${_provider}_pe_arch"
  }

  # A pretty basic target config that just ensures we'll SSH into linux hosts
  # with a specific user and properly escalate to the root user
  $_target_config = {
    'config' => {
      'ssh' => {
        'user'           => $ssh_user,
        'host-key-check' => false,
        'run-as'         => 'root',
        'tty'            => true,
      },
    },
  }

  $native_ssh_config = {
    'config' => {
      'ssh' => {
        'native-ssh'  => true,
        'ssh-command' => 'ssh',
      },
    },
  }

  $target_config = $native_ssh ? {
    true  => deep_merge($_target_config, $native_ssh_config),
    false => $_target_config
  }

  # Generate an inventory of freshly provisioned nodes using the parameters that
  # are appropriate based on which cloud provider we've chosen to use. Utilizes
  # different name and uri parameters to allow for the target's SSH address to
  # differ from the names used to configure Puppet on the internal interfaces
  $inventory = ['server', 'psql', 'compiler'].reduce({}) |Hash $memo, String $i| {
    $memo + { $i => resolve_references({
          '_plugin'        => 'terraform',
          'dir'            => $tf_dir,
          'resource_type'  => $_provider ? {
            'google' => "google_compute_instance.${i}",
            'aws'    => "aws_instance.${i}",
            'azure'  => "azurerm_linux_virtual_machine.${i}",
          },
          'target_mapping' => $_provider ? {
            'google' => {
              'name'         => 'metadata.internalDNS',
              'uri'          => $ssh_ip_mode ? {
                'private' => 'network_interface.0.network_ip',
                default   => 'network_interface.0.access_config.0.nat_ip',
              },
            },
            'aws' => {
              'name' => 'tags.internalDNS',
              'uri'  => $ssh_ip_mode ? {
                'private' => 'private_ip',
                default   => 'public_ip',
              },
            },
            'azure' => {
              'name' => 'tags.internalDNS',
              'uri'  => $ssh_ip_mode ? {
                'private' => 'private_ip_address',
                default   => 'public_ip_address',
              },
            }
          },
      })
    }
  }

  $inventory.each |$k, $v| { $v.each |$target| {
      Target.new($target.merge($target_config)).add_to_group('peadm_nodes')
  } }

  $peadm_configs = run_task('peadm::get_peadm_config', [
      get_targets([
          getvar('inventory.server.0.name'),
          getvar('inventory.server.1.name'),,
      ].peadm::flatten_compact)
  ])

  if ($peadm_configs.count == 1) or ($peadm_configs[0].value == $peadm_configs[1].value) {
    $current_config = $peadm_configs[0].value
  } else {
    fail_plan('Collected PEADM configs do not match, primary and replica must report equal configurations to upgrade')
  }

  $params = {
    'primary_host'            => getvar('current_config.params.primary_host'),
    'primary_postgresql_host' => getvar('current_config.params.primary_postgresql_host'),
    'replica_host'            => getvar('current_config.params.replica_host'),
    'replica_postgresql_host' => getvar('current_config.params.replica_postgresql_host'),
    'compiler_hosts'          => getvar('current_config.params.compilers'),
    'compiler_pool_address'   => getvar('current_config.params.compiler_pool_address'),
    'version'                 => $version,
  }

  $peadm_upgrade_params = $params + $extra_peadm_params

  out::verbose("params var content:\n\n${peadm_upgrade_params}\n")

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $peadm_upgrade_params)
}
