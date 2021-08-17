plan autope::upgrade(
  String                               $version             = '2021.0.0',
  Integer                              $compiler_count      = 1,
  Enum['google', 'aws', 'azure']       $provider            = 'aws',
  String[1]                            $ssh_user            = $provider ? { 'aws' => 'centos', default => undef },
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = ".terraform/${provider}_pe_arch"

  $terraform_output = run_task('terraform::output', 'localhost', dir => $tf_dir)
  $applied = $terraform_output.first

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

  $inventory = ['server', 'psql', 'compiler' ].reduce({}) |Hash $memo, String $i| {
    $memo + { $i => resolve_references({
        '_plugin'        => 'terraform',
        'dir'            => $tf_dir,
        'resource_type'  => $provider ? {
          'google' => "google_compute_instance.${i}",
          'aws'    => "aws_instance.${i}",
          'azure'  => "azurerm_linux_virtual_machine.${i}",
        },
        'target_mapping' => $provider ? {
          'google' => {
            'name' => 'metadata.internalDNS',
            'uri'  => 'network_interface.0.access_config.0.nat_ip',
          },
          'aws' => {
            'name' => 'private_dns',
            'uri'  => 'public_ip',
          },
          'azure' => {
            'name' => 'tags.internal_fqdn',
            'uri'  => 'public_ip_address',
          }
        }
      })
    }
  }

  $inventory.each |$k, $v| { $v.each |$target| {
    Target.new($target.merge($target_config)).add_to_group('peadm_nodes')
  }}

  $params = {
    'primary_host'            => getvar('inventory.server.0.name'),
    'primary_postgresql_host' => getvar('inventory.psql.0.name'),
    'replica_host'            => getvar('inventory.server.1.name'),
    'replica_postgresql_host' => getvar('inventory.psql.1.name'),
    'compiler_hosts'          => getvar('inventory.compiler').map |$c| { $c['name'] },
    'compiler_pool_address'   => $applied['pool']['value'],
    'download_mode'           => 'direct',
    'version'                 => $version
  }

  out::verbose("params var content:\n\n${params}\n")

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $params)
}
