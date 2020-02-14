plan autope::destroy(
  TargetSpec              $targets          = get_targets('pe_adm_nodes'),
  String                  $gcp_project      = 'oppenheimer',
  String                  $ssh_user         = 'oppenheimer',
  Enum['google']          $provider         = 'google'
) {

  $tf_dir = "ext/terraform/${provider}_pe_arch"

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
    |-TFVARS

  # Creating an on-disk tfvars file to be used by Terraform::Apply to avoid a
  # shell escaping issue I couldn't pin down in a reasonable amount of time
  #
  # with_tempfile_containing() custom function suggestion by Cas is brilliant
  # for this, works perfectly
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
