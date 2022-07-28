# @summary Destroy a pecdm provisioned PE cluster
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
