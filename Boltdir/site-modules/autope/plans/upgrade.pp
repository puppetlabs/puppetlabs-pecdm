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
        'master_host'                    => $apply['infrastructure']['value']['masters'][0][0],
        'puppetdb_database_host'         => $apply['infrastructure']['value']['psql'][0][0],
        'master_replica_host'            => $apply['infrastructure']['value']['masters'][1][0],
        'puppetdb_database_replica_host' => $apply['infrastructure']['value']['psql'][1][0],
        'compiler_hosts'                 => $apply['infrastructure']['value']['compilers'].map |$c| { $c[0] },
        'version'                        => $version
      }
    }
    'large': {
      $params = {
        'master_host'                    => $apply['infrastructure']['value']['masters'][0][0],
        'compiler_hosts'                 => $apply['infrastructure']['value']['compilers'].map |$c| { $c[0] },
        'version'                        => $version
      }
    }
    default: { fail('Something went horribly wrong') }
  }

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $params)
}
