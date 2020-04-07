plan autope::destroy(
  TargetSpec              $targets          = get_targets('pe_adm_nodes'),
  String                  $project          = 'oppenheimer',
  String                  $ssh_user         = 'oppenheimer',
  Enum['google', 'aws']   $provider         = 'google'
) {

  Target.new('name' => 'localhost', 'config' => { 'transport' => 'local'})

  $tf_dir = "ext/terraform/${provider}_pe_arch"

  if $provider == 'aws' {
    waring('AWS provider is currently expiremental and may change in a future release')
  }

  $vars_template = @(TFVARS)
    <% unless $project == undef { -%>
    project        = "<%= $project %>"
    <% } -%>
    user           = "<%= $ssh_user %>"
    destroy        = true
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
