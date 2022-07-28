# @summary Destroy a pecdm provisioned PE cluster
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
