plan autope::upgrade(
  TargetSpec              $targets          = get_targets('pe_adm_nodes'),
  String                  $version          = '2019.3.0',
  String                  $ssh_user,
  Enum['xlarge', 'large'] $architecture     = 'xlarge',
  Enum['google']          $provider         = 'google'
) {

  $tf_dir = "ext/terraform/${provider}_pe_arch/${architecture}"

  $apply = run_task('terraform::output', 'localhost', dir => $tf_dir).first.value

  # Intentionally not using Bolt inventory plugin for Terraform to enable the
  # dynamic sourcing of node names by abstracting the differences inherent in
  # the resources names stored in the TF state file to allow the addition of
  # support for cloud providers beyond GCP. In addition, we must construct the
  # inventory node name from multiple properties of the resource, a feature not
  # available from the current inventory plugin.
  $apply['infrastructure']['value'].each |$k,$v| { $v.each |$s| {
    Target.new({
      'name'   => $s[0],
      'uri'    => $s[1],
      'config' => {
        'ssh' => {
          'user'           => $ssh_user,
          'host-key-check' => false,
          'run-as'         => 'root',
          'tty'            => true
        }
      }
    }).add_to_group('pe_adm_nodes')
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
