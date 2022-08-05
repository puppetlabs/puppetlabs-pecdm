# @summary Write to current working directory a provider specific inventory.yaml
#
# @param provider
#   Which cloud provider that infrastructure will be provisioned into
#
# @param ssh_ip_mode
#   The type of IPv4 address that will be used to gain SSH access to instances
#
# @param windows_runner
#   Set to true if the pecdm plan is being ran on Windows 
#
plan pecdm::utils::inventory_yaml(
  Enum['google', 'aws', 'azure'] $provider,
  Enum['private', 'public']      $ssh_ip_mode,
  Boolean                        $windows_runner = false,
) {

  out::message("Writing inventory.yaml for ${provider}")

  file::write('inventory.yaml', epp('pecdm/inventory_yaml.epp', {
    provider       => $provider,
    ssh_ip_mode    => $ssh_ip_mode,
    windows_runner => $windows_runner
  }))
}
