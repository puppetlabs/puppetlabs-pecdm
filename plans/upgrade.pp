# @summary Upgrade a pecdm provisioned cluster
#
plan pecdm::upgrade(
  String[1]                                 $version            = '2021.5.0',
  Hash                                      $extra_peadm_params = {},
  # The final three parameters depend on the value of $provider, to do magic
  Enum['google', 'aws', 'azure']            $provider,
  String[1]                                 $project            = $provider ? { 'aws' => 'ape', default => undef },
  String[1]                                 $ssh_user           = $provider ? { 'aws' => 'centos', default => undef },
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = ".terraform/${provider}_pe_arch"

  run_command("cd ${tf_dir} && terraform refresh", 'localhost')

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

  $pecdm_targets = $inventory.map |$_, $v| { $v.map |$target| {
    Target.new($target.merge($target_config))
  }}.flatten

  wait_until_available($pecdm_targets, wait_time => 300)

  $compiler_pool_address = $terraform_output['pool']['value']
  $params = pecdm::peadm_params_from_configuration($inventory, $compiler_pool_address, $version)

  out::verbose("params var content:\n\n${params}\n")

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $params + $extra_peadm_params)
}
