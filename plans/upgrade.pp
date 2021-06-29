plan autope::upgrade(
  TargetSpec                           $targets          = get_targets('peadm_nodes'),
  String                               $version          = '2019.3.0',
  String                               $ssh_user,
  Enum['xlarge', 'large', 'starndard'] $architecture     = 'xlarge',
  Enum['google', 'aws', 'azure']       $provider         = 'google'
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = ".terraform/${provider}_pe_arch"

  if $provider == 'aws' {
    waring('AWS provider is currently expiremental and may change in a future release')
  }

  $target_config = {
    'config' => {
      'ssh' => {
        'user'           => $ssh_user,
        'host-key-check' => false,
        'run-as'         => 'root',
        'tty'            => true
      }
    }
  }

  $inventory = ['master', 'psql', 'compiler' ].reduce({}) |Hash $memo, String $i| {
    $memo + { $i => resolve_references({
        '_plugin'        => 'terraform',
        'dir'            => $tf_dir,
        'resource_type'  => $provider ? {
          'google' => "google_compute_instance.${i}",
          'aws'    => "aws_instance.${i}",
          'azure'  => "azurerm_linux_virtual_machine.${i}_public_ip",
        },
        'target_mapping' => $provider ? {
          'google' => {
            'name' => 'metadata.internalDNS',
            'uri'  => 'network_interface.0.access_config.0.nat_ip',
          },
          'aws' => {
            'name' => 'public_dns',
            'uri'  => 'public_ip',
          },
          'azure' => {
            'fqdn' => 'public_dns',
            'uri'  => 'ip_address',
          }
        }
      })
    }
  }

  $inventory.each |$k, $v| { $v.each |$target| {
    Target.new($target.merge($target_config)).add_to_group('peadm_nodes')
  }}

  case $architecture {
    'xlarge': {
      $params = {
        'master_host'                    => $inventory['master'][0]['name'],
        'master_replica_host'            => $inventory['master'][1]['name'],
        'puppetdb_database_host'         => $inventory['psql'][0]['name'],
        'puppetdb_database_replica_host' => $inventory['psql'][1]['name'],
        'compiler_hosts'                 => $inventory['compiler'].map |$c| { $c['name'] },
        'console_password'               => $console_password,
        'dns_alt_names'                  => [ 'puppet', $apply['pool']['value'] ],
        'compiler_pool_address'          => $apply['pool']['value'],
        'version'                        => $version
      }
    }
    'large': {
      $params = {
        'master_host'                    => $inventory['master'][0]['name'],
        'compiler_hosts'                 => $inventory['compiler'].map |$c| { $c['name'] },
        'console_password'               => $console_password,
        'dns_alt_names'                  => [ 'puppet', $apply['pool']['value'] ],
        'compiler_pool_address'          => $apply['pool']['value'],
        'version'                        => $version
      }
    }
    'standard': {
      $params = {
        'master_host'                    => $inventory['master'][0]['name'],
        'console_password'               => $console_password,
        'dns_alt_names'                  => [ 'puppet', $apply['pool']['value'] ],
        'compiler_pool_address'          => $apply['pool']['value'],
        'version'                        => $version
      }
    }
    default: { fail('Something went horribly wrong or only xlarge is supported in this configuration') }
  }

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $params)
}
