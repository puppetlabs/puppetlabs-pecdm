# @summary Destroy a pecdm provisioned Puppet Enterprise cluster
#
# @param provider
#   Which cloud provider that infrastructure will be provisioned into
#
# @param cloud_region
#   Which region to provision infrastructure in, if not provided default will
#   be determined by provider
#
plan pecdm::subplans::destroy(
  Enum['google', 'aws', 'azure']  $provider,
  String[1]                       $cloud_region = $provider ? { 'azure' => 'westus2' ,'aws' => 'us-west-2', default => 'us-west1' }
) {

  out::message("Destroying Puppet Enterprise deployment on ${provider}")

  $tf_dir = ".terraform/${provider}_pe_arch"

  # Ensure the Terraform project directory has been initialized ahead of
  # attempting a destroy
  run_task('terraform::initialize', 'localhost', dir => $tf_dir)

  $vars_template = @(TFVARS)
    <% unless $cloud_region == undef { -%>
    region        = "<%= $cloud_region %>"
    <% } -%>
    <% if $provider == 'google' { -%>
    destroy        = true
    <% } -%>
    # Required parameters which values are irrelevant on destroy
    project        = "oppenheimer"
    user           = "oppenheimer"
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

  out::message('Puppet Enterprise deployment successfully destroyed')
}
