plan autope(
  TargetSpec                          $targets            = get_targets('peadm_nodes'),
  Enum['xlarge', 'large', 'standard'] $architecture       = 'standard',
  String[1]                           $version            = '2019.8.5',
  String[1]                           $console_password   = 'puppetlabs',
  Integer                             $compiler_count     = 1,
  Optional[String[1]]                 $ssh_pub_key_file   = undef,
  Optional[Integer]                   $node_count         = undef,
  Optional[String[1]]                 $instance_image     = undef,
  Optional[String[1]]                 $stack              = undef,
  Array                               $firewall_allow     = [],
  Hash                                $extra_peadm_params = {},
  Boolean                             $replica            = false,
  Boolean                             $stage              = false,
  # The final three parameters depend on the value of $provider, to do magic
  Enum['google', 'aws', 'azure']      $provider,
  String[1]                           $project            = $provider ? { 'aws' => 'ape', default => undef },
  String[1]                           $ssh_user           = $provider ? { 'aws' => 'centos', default => undef },
  String[1]                           $cloud_region       = $provider ? { 'azure' => 'westus2', 'aws' => 'us-west-2', default => 'us-west1' }, # lint:ignore:140chars
) {

  # Ensure that actions that operate on localhost use the local transport, else
  # Bolt will probably try to use SSH and most likely fail
  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  # Where r10k deploys our various Terraform modules for each cloud provider
  $tf_dir = ".terraform/${provider}_pe_arch"

  # Ensure the Terraform project directory has been initialized ahead of
  # attempting an apply
  run_task('terraform::initialize', 'localhost', dir => $tf_dir)

  # Mapping all the plan parameters to their corresponding Terraform vars,
  # choosing to maintain a mirrored list so I can leverage the flexibility
  # of Puppet expressions, typing, and documentation
  #
  # Quoting is important in a Terraform vars file so we take care in preserving
  # them and converting single quotes to double. Chose to use an inline_epp
  # instead of pure HEREDOC to allow for the use of conditionals
  $vars_template = @(TFVARS)
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
    stack_name = "<%= $stack %>"
    <% } -%>
    firewall_allow = <%= String($firewall_allow).regsubst('\'', '"', 'G') %>
    architecture   = "<%= $architecture %>"
    replica        = <%= $replica %>
    |TFVARS

  $tfvars = inline_epp($vars_template)

  # Creating an on-disk tfvars file to be used by Terraform::Apply to avoid a
  # shell escaping issue I couldn't pin down in a reasonable amount of time
  #
  # with_tempfile_containing() custom function suggestion by Cas is brilliant
  # for this, works perfectly
  $apply = autope::with_tempfile_containing('', $tfvars, '.tfvars') |$tfvars_file| {
    # Stands up our cloud infrastructure that we'll install PE onto, returning a
    # specific set of data via TF outputs that if replicated will make this plan
    # easily adaptable for use with multiple cloud providers
    run_plan('terraform::apply',
      dir           => $tf_dir,
      return_output => true,
      var_file      => $tfvars_file
    )
  }

  # A pretty basic target config that just ensures we'll SSH into linux hosts
  # with a specific user and properly escalate to the root user, ignores host
  # keys because this is largely disposable infrastructure
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

  # Generate an inventory of freshly provisioned nodes using the parameters that
  # are appropriate based on which cloud provider we've chosen to use. Utilizes
  # different name and uri parameters to allow for the target's SSH address to
  # differ from the names used to configure Puppet on the internal interfaces
  $inventory = ['server', 'psql', 'compiler', 'node' ].reduce({}) |Hash $memo, String $i| {
    $memo + { $i => resolve_references({
        '_plugin'        => 'terraform',
        'dir'            => $tf_dir,
        'resource_type'  => $provider ? {
          'google' => "google_compute_instance.${i}",
          'aws'    => "aws_instance.${i}",
          'azure'  => "azurerm_public_ip.${i}_public_ip",
        },
        'target_mapping' => $provider ? {
          'google' => {
            'name' => 'metadata.internalDNS',
            'uri'  => 'network_interface.0.access_config.0.nat_ip',
          },
          'aws'    => {
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

  # Create and Target objects from our previously generated inventory and add
  # them to the peadm_nodes group and agent_nodes
  $inventory.each |$k, $v| { $v.each |$target| {
    Target.new($target.merge($target_config)).add_to_group('peadm_nodes')
  }}

  $inventory['node'].each |$target| {
    Target.new($target.merge($target_config)).add_to_group('agent_nodes')
  }

  # Generate a parameters list to be fed to puppetlabs/peadm based on which
  # architecture we've chosen to deploy. The default case should never be
  # reached since any architecture has been previously validated.
  case $architecture {
    'xlarge': {
      $base_params = {
        'primary_host'            => $inventory['server'][0]['name'],
        'puppetdb_database_host' => $inventory['psql'][0]['name'],
        'compiler_hosts'         => $inventory['compiler'].map |$c| { $c['name'] },
        'console_password'       => $console_password,
        'dns_alt_names'          => [ 'puppet', $apply['pool']['value'] ],
        'compiler_pool_address'  => $apply['pool']['value'],
        'version'                => $version
      }
      if $replica {
        $params = merge($base_params, {
          'primary_replica_host'            => $inventory['server'][1]['name'],
          'puppetdb_database_replica_host' => $inventory['psql'][1]['name'],
        })
      } else {
        $params = $base_params
      }
    }
    'large': {
      $base_params = {
        'primary_host'           => $inventory['server'][0]['name'],
        'compiler_hosts'        => $inventory['compiler'].map |$c| { $c['name'] },
        'console_password'      => $console_password,
        'dns_alt_names'         => [ 'puppet', $apply['pool']['value'] ],
        'compiler_pool_address' => $apply['pool']['value'],
        'version'               => $version
      }
      if $replica {
        $params = merge($base_params, {
          'primary_replica_host' => $inventory['server'][1]['name'],
        })
      } else {
        $params = $base_params
      }
    }
    'standard': {
      $base_params = {
        'primary_host'           => $inventory['server'][0]['name'],
        'console_password'      => $console_password,
        'dns_alt_names'         => [ 'puppet', $apply['pool']['value'] ],
        'compiler_pool_address' => $apply['pool']['value'],
        'version'               => $version
      }
      if $replica {
        $params = merge($base_params, {
          'primary_replica_host' => $inventory['server'][1]['name'],
        })
      } else {
        $params = $base_params
      }
    }
    default: { fail('Something went horribly wrong') }
  }

  unless $stage {
    # Once all the infrastructure data has been collected, handoff to puppetlabs/peadm
    run_plan('peadm::provision', $params + $extra_peadm_params)

    if $node_count {
      # Annoying work around for AWS not setting the hostname we want. Doing this
      # only for AWS to keep concurrency when doing GCP and would prefer to solve
      # this issue from within Terraform but could not come up with clean solution
      # without further discovery, Bolt's a good hammer
      if $provider == 'aws' {
        get_targets('agent_nodes').parallelize |$a| {
          run_task('peadm::agent_install', $a, {
            'server' => $apply['pool']['value'],
            'install_flags' => ["agent:certname=${a.name}"]
            }
          )
        }
      } else {
        run_task('peadm::agent_install', get_targets('agent_nodes'), { 'server' => $apply['pool']['value'] })
      }
      run_task('peadm::sign_csr', $inventory['server'][0]['name'], { 'certnames' => get_targets('agent_nodes').map |$a| { $a.name }  })
    }
  }

  $console = $apply['console']['value']
  out::message("Log into Puppet Enterprise Console: https://${console}")
}
