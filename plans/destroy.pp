plan autope::destroy(
  TargetSpec              $targets          = get_targets('peadm_nodes'),
  Enum['google', 'aws']   $provider         = 'google',
  String[1]               $project          = $provider ? { 'aws' => 'ape', default => 'oppenheimer' },
  String[1]               $ssh_user         = $provider ? { 'aws' => 'centos', default => 'oppenheimer' },
  String[1]               $cloud_region     = $provider ? { 'aws' => 'us-west-2', default => 'us-west1' },
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = "ext/terraform/${provider}_pe_arch"

  $vars_template = @(TFVARS)
    <% unless $project == undef { -%>
    project        = "<%= $project %>"
    <% } -%>
    <% unless $cloud_region == undef { -%>
    region        = "<%= $cloud_region %>"
    <% } -%>
    user           = "<%= $ssh_user %>"
    <% if $provider == 'google' { -%>
    destroy        = true
    <% } -%>
    |TFVARS

  $tfvars = inline_epp($vars_template)

  autope::with_tempfile_containing('', $tfvars, '.tfvars') |$tfvars_file| {
    # Stands up our cloud infrastructure that we'll install PE onto, returning a
    # specific set of data via TF outputs that if replicated will make this plan
    # easily adaptable for use with multiple cloud providers
    run_plan('terraform::destroy',
      dir           => $tf_dir,
      var_file      => $tfvars_file
    )
  }
}
