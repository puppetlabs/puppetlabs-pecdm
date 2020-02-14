plan autope(
  TargetSpec              $targets          = get_targets('pe_adm_nodes'),
  String                  $version          = '2019.3.0',
  String                  $console_password = 'puppetlabs',
  String                  $gcp_project,
  String                  $ssh_user,
  String                  $ssh_pub_key_file = '~/.ssh/id_rsa.pub',
  String                  $cloud_region     = 'us-west1',
  Array                   $cloud_zones      = ["${cloud_region}-a", "${cloud_region}-b", "${cloud_region}-c"],
  Integer                 $compiler_count   = 3,
  String                  $instance_image   = 'centos-cloud/centos-7',
  Array                   $firewall_allow   = [],
  Enum['xlarge', 'large'] $architecture     = 'xlarge',
  Enum['google']          $provider         = 'google'
) {

  $tf_dir = "ext/terraform/${provider}_pe_arch"

  $allow_with_internal = $firewall_allow << '10.128.0.0/9'

  # Ensure the Terraform project directory has been initialized ahead of
  # attempting an apply
  run_task('terraform::initialize', 'localhost', dir => $tf_dir)

  # Mapping all the plan parameters to their corresponding Terraform vars,
  # choosing to maintain a mirrored list so I can leverage the flexibility
  # of Puppet expressions, typing, and documentation
  #
  # Converting Array typed parameters to Strings to prevent HEREDOC from
  # stripping quotes and ensuring the quotes used are " instead of ', which are
  # both required to exist in the tfvars file. Attempted to use a type
  # conversion formatter instead of regsubst() but couldn't get it to work and
  # docs are sparse on how it's suppose to work
  $tfvars = @("TFVARS")
    project        = "${gcp_project}"
    user           = "${ssh_user}"
    ssh_key        = "${ssh_pub_key_file}"
    region         = "${cloud_region}"
    zones          = ${String($cloud_zones).regsubst('\'', '"', 'G')}
    compiler_count = ${compiler_count}
    instance_image = "${instance_image}"
    firewall_allow = ${String($allow_with_internal).regsubst('\'', '"', 'G')}
    architecture   = "${architecture}"
    |-TFVARS

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
    default: { fail('Something went horribly wrong or only xlarge is supported in this configuration') }
  }

  # Once all the infrastructure data has been collected, peadm takes over
  run_plan('peadm::provision', $params)
}
