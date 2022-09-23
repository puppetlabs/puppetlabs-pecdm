# @summary Destroy a pecdm provisioned Puppet Enterprise cluster
#
# @param provider
#   Which cloud provider that infrastructure will be provisioned into
#
# @param cloud_region
#   Which region to provision infrastructure in, if not provided default will
#   be determined by provider
#
plan pecdm::destroy(
  Enum['google', 'aws', 'azure']  $provider,
  Optional[String[1]]             $cloud_region = undef
) {
  run_plan('pecdm::subplans::destroy', {
      provider     => $provider,
      cloud_region => $cloud_region
  })
}
