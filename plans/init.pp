plan autope(
  TargetSpec                          $targets            = get_targets('peadm_nodes'),
  Enum['xlarge', 'large', 'standard'] $architecture       = 'large',
  Enum['google', 'aws']               $provider           = 'google',
  String                              $version            = '2019.5.0',
  String                              $console_password   = 'puppetlabs',
  String                              $ssh_pub_key_file   = '~/.ssh/id_rsa.pub',
  String                              $cloud_region       = 'us-west1',
  Integer                             $compiler_count     = 3,
  Optional[Integer]                   $node_count         = undef,
  String                              $instance_image     = 'centos-cloud/centos-7',
  Array                               $firewall_allow     = [],
  Hash                                $extra_peadm_params = {},
  String                              $project,
  String                              $ssh_user,
) {

  # Ensure that actions that operate on localhost use the local transport, else
  # Bolt will probably try to use SSH and most likely fail
  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  # Where r10k deploys our various Terraform modules for each cloud provider
  $tf_dir = "ext/terraform/${provider}_pe_arch"

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
    <% unless $project == undef { -%>
    project        = "<%= $project %>"
    <% } -%>
    user           = "<%= $ssh_user %>"
    ssh_key        = "<%= $ssh_pub_key_file %>"
    region         = "<%= $cloud_region %>"
    compiler_count = <%= $compiler_count %>
    <% unless $node_count == undef { -%>
    node_count     = "<%= $node_count %>"
    <% } -%>
    instance_image = "<%= $instance_image %>"
    firewall_allow = <%= String($firewall_allow).regsubst('\'', '"', 'G') %>
    architecture   = "<%= $architecture %>"
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
  $inventory = ['master', 'psql', 'compiler', 'node' ].reduce({}) |Hash $memo, String $i| {
    $memo + { $i => resolve_references({
        '_plugin'        => 'terraform',
        'dir'            => $tf_dir,
        'resource_type'  => $provider ? {
          'google' => "google_compute_instance.${i}",
          'aws'    => "aws_instance.${i}",
        },
        'target_mapping' => $provider ? {
          'google' => {
            'name' => 'metadata.internalDNS',
            'uri'  => 'network_interface.0.access_config.0.nat_ip',
          },
          'aws' => {
            'name' => 'public_dns',
            'uri'  => 'public_ip',
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
    default: { fail('Something went horribly wrong') }
  }

  # Once all the infrastructure data has been collected, handoff to puppetlabs/peadm
  run_plan('peadm::provision', $params + $extra_peadm_params)

  if $node_count {
    run_task('peadm::agent_install', get_targets('agent_nodes'), { 'server' => $apply['pool']['value'] })
    # Just in case, sleep 5...just in case...
    ctrl::sleep(5)
    run_task('peadm::sign_csr', $inventory['master'][0]['name'], { 'certnames' => get_targets('agent_nodes').map |$a| { $a.name }  })
  }

  $console = $apply['console']['value']
  out::message("Log into Puppet Enterprise Console: https://${console}")
}
