# @summary Destroy a pecdm provisioned PE cluster
#
plan pecdm::destroy(
  TargetSpec                       $targets          = get_targets('peadm_nodes'),
  Enum['google', 'aws', 'azure']   $provider         = 'google',
  String[1]                        $project          = $provider ? { 'aws' => 'ape', default => 'oppenheimer' },
  String[1]                        $ssh_user         = $provider ? { 'aws' => 'centos', default => 'oppenheimer' },
  String[1]                        $cloud_region     = $provider ? { 'azure' => 'westus2' ,'aws' => 'us-west-2', default => 'us-west1' },
  Optional[String[1]]              $ssh_pub_key_file = undef,
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = ".terraform/${provider}_pe_arch"

  # Ensure the Terraform project directory has been initialized ahead of
  # attempting a destroy
  run_task('terraform::initialize', 'localhost', dir => $tf_dir)

  $vars_template = @(TFVARS)
    <% unless $project == undef { -%>
    project        = "<%= $project %>"
    <% } -%>
    <% unless $cloud_region == undef { -%>
    region        = "<%= $cloud_region %>"
    <% } -%>
    user           = "<%= $ssh_user %>"
    <% unless $ssh_pub_key_file == undef { -%>
    ssh_key        = "<%= $ssh_pub_key_file %>"
    <% } -%>
    <% if $provider == 'google' { -%>
    destroy        = true
    <% } -%>
    |TFVARS

  $tfvars = inline_epp($vars_template)

  pecdm::with_tempfile_containing('', $tfvars, '.tfvars') |$tfvars_file| {
    # Stands up our cloud infrastructure that we'll install PE onto, returning a
    # specific set of data via TF outputs that if replicated will make this plan
    # easily adaptable for use with multiple cloud providers
    run_plan('terraform::destroy',
      dir           => $tf_dir,
      var_file      => $tfvars_file
    )
  }
}
