# @summary Upgrade a pecdm provisioned cluster
#
plan pecdm::upgrade(
  String                               $version             = '2021.2.0',
  Integer                              $compiler_count      = 1,
  Enum['google', 'aws', 'azure']       $provider,
  String[1]                            $ssh_user            = $provider ? { 'aws' => 'centos', default => undef },
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = ".terraform/${provider}_pe_arch"

  $terraform_output = run_task('terraform::output', 'localhost', dir => $tf_dir).first

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
            'uri'  => getvar('apply.ip_path.value', 'network_interface.0.access_config.0.nat_ip'),
          },
          'aws' => {
            'name' => 'private_dns',
            'uri'  => getvar('apply.ip_path.value', 'public_ip'),
          },
          'azure' => {
            'name' => 'tags.internal_fqdn',
            'uri'  => getvar('apply.ip_path.value', 'public_ip_address'),
          }
        }
      })
    }
  }

  $inventory.each |$k, $v| { $v.each |$target| {
    Target.new($target.merge($target_config)).add_to_group('peadm_nodes')
  }}

  $compiler_pool_adress = $terraform_output['pool']['value']
  $params = pecdm::peadm_params_from_configuration($inventory, $compiler_pool_adress, $version)

  out::verbose("params var content:\n\n${params}\n")

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $params)
}
