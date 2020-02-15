plan autope::upgrade(
  TargetSpec              $targets          = get_targets('pe_adm_nodes'),
  String                  $version          = '2019.3.0',
  String                  $ssh_user,
  Enum['xlarge', 'large'] $architecture     = 'xlarge',
  Enum['google']          $provider         = 'google'
) {

  $tf_dir = "ext/terraform/${provider}_pe_arch"

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
        'resource_type'  => "google_compute_instance.${i}",
        'target_mapping' => {
          'name' => 'metadata.internalDNS',
          'uri'  => 'network_interface.0.access_config.0.nat_ip',
        }
      })
    }
  }

  $inventory.each |$k, $v| { $v.each |$target| {
    Target.new($target.merge($target_config)).add_to_group('pe_adm_nodes')
  }}

  case $architecture {
    'xlarge': {
      $params = {
        'master_host'                    => $inventory['master'][0]['name'],
        'master_replica_host'            => $inventory['master'][1]['name']
        'puppetdb_database_host'         => $inventory['psql'][0]['name'],
        'puppetdb_database_replica_host' => $inventory['psql'][1]['name'], 
        'compiler_hosts'                 => $inventory['compiler'].map |$c| { $c['name'] },
        'version'                        => $version
      }
    }
    'large': {
      $params = {
        'master_host'    => $inventory['master'][0]['name'],
        'compiler_hosts' => $inventory['compiler'].map |$c| { $c['name'] },
        'version'        => $version
      }
    }
    default: { fail('Something went horribly wrong') }
  }

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $params)
}
