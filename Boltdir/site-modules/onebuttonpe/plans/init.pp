plan onebuttonpe(
  TargetSpec $targets          = get_targets('pe_adm_nodes'),
  String     $version          = '2019.2.2',
  String     $console_password = 'puppetlabs',
  String     $gcp_project,
  String     $ssh_user,
  String     $ssh_pub_key_file = '~/.ssh/id_rsa.pub',
  String     $cloud_region     = 'us-west1',
  Array      $cloud_zones      = ["${cloud_region}-a", "${cloud_region}-b", "${cloud_region}-c"],
  Integer    $compiler_count   = 3,
  String     $instance_image   = 'centos-cloud/centos-7',
  Array      $firewall_allow   = ['10.128.0.0/9']
) {

  $tfvars = @("TFVARS")
    project        = "${gcp_project}"
    user           = "${ssh_user}"
    ssh_key        = "${ssh_pub_key_file}"
    region         = "${cloud_region}"
    zones          = ${String($cloud_zones).regsubst('\'', '"', 'G')}
    compiler_count = ${compiler_count}
    instance_image = "${instance_image}"
    firewall_allow = ${String($firewall_allow).regsubst('\'', '"', 'G')}
    |-TFVARS

  $tfvars_file = "/tmp/tfvars.${rand_string(8)}"

  run_task('peadm::mkdir_p_file', localhost,
    path    => $tfvars_file,
    content => $tfvars
  )

  $apply = run_plan('terraform::apply',
    dir           => 'terraform',
    return_output => true,
    var_file      => $tfvars_file
  )

  # Intentionally not using Bolt inventory plugin for Terraform to enable the
  # dynamic sourcing of node names by abstracting the differences inherint in
  # the resources names stored in the TF state file to allow the addition of
  # support for cloud providers beyond GCP. In addition, we must construct the
  # inventory node name from multiple properties of the resource, a feature not
  # available from the current inventory plugin.
  $apply['infrastructure']['value'].each |$k,$v| { $v.each |$s| {
    Target.new({'name' => $s[0], 'uri' => $s[1]}).add_to_group('pe_adm_nodes')
  } }

  run_plan('peadm::provision', {
      'master_host'                    => $apply['infrastructure']['value']['masters'][0][0],
      'puppetdb_database_host'         => $apply['infrastructure']['value']['psql'][0][0],
      'master_replica_host'            => $apply['infrastructure']['value']['masters'][1][0],
      'puppetdb_database_replica_host' => $apply['infrastructure']['value']['psql'][1][0],
      'compiler_hosts'                 => $apply['infrastructure']['value']['compilers'].map |$c| { $c[0] },
      'console_password'               => $console_password,
      'dns_alt_names'                  => [ 'puppet', $apply['pool']['value'] ],
      'compiler_pool_address'          => $apply['pool']['value'],
      'version'                        => $version
    }
  )

  run_command("rm ${tfvars_file}", localhost)
}
