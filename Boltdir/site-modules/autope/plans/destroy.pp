plan autope::destroy(
  TargetSpec              $targets          = get_targets('pe_adm_nodes'),
  String                  $version          = '2019.2.2',
  String                  $console_password = 'puppetlabs',
  String                  $gcp_project,
  String                  $ssh_user         = 'oppenheimer',
  String                  $ssh_pub_key_file = '~/.ssh/id_rsa.pub',
  String                  $cloud_region     = 'us-west1',
  Array                   $cloud_zones      = ["${cloud_region}-a", "${cloud_region}-b", "${cloud_region}-c"],
  Integer                 $compiler_count   = 3,
  String                  $instance_image   = 'centos-cloud/centos-7',
  Array                   $firewall_allow   = ['10.128.0.0/9'],
  Enum['xlarge', 'large'] $architecture     = 'xlarge'
) {

  # Mapping all the plan parameters to their corresponding Terraform vars,
  # choosing to maintain a mirrored list so I can leverage the flexibility
  # of Puppet expressions, typing, and documentation
  #
  # Converting Array typed parameters to Strings to prevent HEREDOC from
  # strippng quotes and ensuring the quotes used are " instead of ', which are
  # both requied to exist in the tfvars file. Attempted to use a type
  # converstion formatter instead of regsubst() but couldn't get it to work and
  # docs are sparse on how it's suppose to work
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

  # Creating an on-disk tfvars file to be used by Terraform::Apply to avoid a
  # shell escaping issue I couldn't pin down in a reasonable amount of time
  #
  # with_tempfile_containing() custom function suggestion by Cas is brilliant
  # for this, works perfectly
  autope::with_tempfile_containing('', $tfvars, '.tfvars') |$tfvars_file| {
    # Stands up our cloud infrastructure that we'll install PE onto, returning a
    # specific set of data via TF outputs that if replicated will make this plan
    # easily adaptible for use with multiple cloud providers
    run_plan('terraform::destroy',
      dir           => "ext/terraform/pe_arch/${architecture}",
      var_file      => $tfvars_file
    )
  }
}
