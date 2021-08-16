plan autope::upgrade(
  TargetSpec                           $targets             = get_targets('peadm_nodes'),
  String                               $version             = '2019.3.0',
  # String[1]                            $console_password    = 'puppetlabs',
  Integer                              $compiler_count      = 1,
  Optional[String[1]]                  $ssh_pub_key_file    = undef,
  Optional[Integer]                    $node_count          = undef,
  Optional[String[1]]                  $instance_image      = undef,
  Optional[String[1]]                  $stack               = undef,
  Array                                $firewall_allow      = [],
  Hash                                 $extra_peadm_params  = {},
  Boolean                              $replica             = false,
  Enum['xlarge', 'large', 'standard']  $architecture        = 'standard',
  Enum['google', 'aws', 'azure']       $provider            = 'aws',
  String[1]                            $project             = $provider ? { 'aws' => 'ape', default => undef },
  String[1]                            $ssh_user            = $provider ? { 'aws' => 'centos', default => undef },
  String[1]                            $cloud_region        = $provider ? { 'azure' => 'westus2', 'aws' => 'us-west-2', default => 'us-west1' }, # lint:ignore:140chars
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = ".terraform/${provider}_pe_arch"

  if $provider == 'aws' {
    warning('AWS provider is currently expiremental and may change in a future release')
  }

  # WIP
  $tfvars = inline_epp(@(TFVARS))
    project        = "<%= $project %>"
    user           = "<%= $ssh_user %>"
    <% unless $ssh_pub_key_file == undef { -%>
    ssh_key        = "<%= $ssh_pub_key_file %>"
    <% } -%>
    region         = "<%= $cloud_region %>"
    compiler_count = <%= $compiler_count %>
    <% unless $node_count == undef { -%>
    node_count     = "<%= $node_count %>"
    <% } -%>
    <% unless $instance_image == undef { -%>
    instance_image = "<%= $instance_image %>"
    <% } -%>
    <% unless stack == undef { -%>
    stack_name     = "<%= $stack %>"
    <% } -%>
    firewall_allow = <%= String($firewall_allow).regsubst('\'', '"', 'G') %>
    architecture   = "<%= $architecture %>"
    replica        = <%= $replica %>
    | TFVARS

  # TODO: make this print only when user specifies --verbose
  out::verbose(".tfvars file content:\n\n${tfvars}\n")

  $terraform_output = run_task('terraform::output', 'localhost', dir => $tf_dir)
  $applied = $terraform_output.first
  #

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

  # Debugging
  # debug::break()

  case $architecture {
    'xlarge': {
      $params = {
        'primary_host'                   => $inventory['server'][0]['name'],
        'replica_host'                   => $inventory['server'][1]['name'],
        'primary_postgresql_host'        => $inventory['psql'][0]['name'],
        'replica_postgresql_host'        => $inventory['psql'][1]['name'],
        'compiler_hosts'                 => $inventory['compiler'].map |$c| { $c['name'] },
        # 'console_password'               => $console_password,
        # 'dns_alt_names'                  => [ 'puppet', $applied['pool']['value'] ],
        'compiler_pool_address'          => $applied['pool']['value'],
        'version'                        => $version,
        'download_mode'                  => 'direct',
      }
    }
    'large': {
      $params = {
        'primary_host'                    => $inventory['server'][0]['name'],
        'compiler_hosts'                 => $inventory['compiler'].map |$c| { $c['name'] },
        # 'console_password'               => $console_password,
        # 'dns_alt_names'                  => [ 'puppet', $applied['pool']['value'] ],
        'compiler_pool_address'          => $applied['pool']['value'],
        'version'                        => $version,
        'download_mode'                  => 'direct',
      }
    }
    'standard': {
      $params = {
        'primary_host'                    => $inventory['server'][0]['name'],
        # 'console_password'               => $console_password,
        # 'dns_alt_names'                  => [ 'puppet', $applied['pool']['value'] ],
        'compiler_pool_address'          => $applied['pool']['value'],
        'version'                        => $version,
        'download_mode'                  => 'direct',
      }
    }
    default: { fail('Something went horribly wrong or only xlarge is supported in this configuration') }
  }

  # Debugging
  # debug::break()
  # TODO: make this print only when user specifies --verbose
  out::verbose("params var content:\n\n${params}\n")

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::upgrade', $params)
}
