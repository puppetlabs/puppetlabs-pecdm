# @summary Deploy Puppet Enterprise in the cloud by launching peadm with appropriate parameters
#
# @param inventory
#   Node inventory hash provided by Pecdm::Subplans::Provision plan
#
# @param compiler_pool_address
#   The FQDN that agent nodes will connect to for catalog compilation services
#
# @param download_mode
#   The method peadm will use to transfer the PE installer to each
#   infrastructure node
#
# @param version
#   Which PE version to install with peadm
#
# @param console_password
#   Initial admin user console password, if not provided you will be prompted to
#   input one or accept an insecure default
#
# @param dns_alt_names
#   Any additional DNS Alternative Names that must be assigned to PE
#   infrastructure node certificates
#
# @param extra_peadm_params
#   The pecdm plan does not expose all parameters available to peadm, if others
#   are needed then pass a hash
#
plan pecdm::subplans::deploy(
  Hash                                          $inventory,
  String[1]                                     $compiler_pool_address,
  String[1]                                     $console_password,
  Enum['direct', 'bolthost']                    $download_mode        = 'direct',
  String[1]                                     $version              = '2019.8.10',
  Array                                         $dns_alt_names        = [],
  Hash                                          $extra_peadm_params   = {},
) {
  out::message('Starting deployment of Puppet Enterprise')

  $peadm_target_list = $inventory.map |$_, $v| {
    $v.map |$target| {
      $target['name']
    }
  }.flatten()

  # Generate a parameters list to be fed to puppetlabs/peadm based on which
  # architecture we've chosen to deploy. PEAdm will figure out the correct
  # thing to do based on whether or not there are valid values for each
  # architecture component. An empty array is equivalent to not defining the
  # parameter.
  $params = {
    'primary_host'            => getvar('inventory.server.0.name'),
    'primary_postgresql_host' => getvar('inventory.psql.0.name'),
    'replica_host'            => getvar('inventory.server.1.name'),
    'replica_postgresql_host' => getvar('inventory.psql.1.name'),
    'compiler_hosts'          => getvar('inventory.compiler', []).map |$c| { $c['name'] },
    'console_password'        => $console_password,
    'dns_alt_names'           => peadm::flatten_compact(['puppet', $compiler_pool_address] + $dns_alt_names).delete(''),
    'compiler_pool_address'   => $compiler_pool_address,
    'download_mode'           => $download_mode,
    'version'                 => $version
  }

  # TODO: make this print only when user specifies --verbose
  $peadm_install_params = $params + $extra_peadm_params
  out::verbose("peadm::install params:\n\n${peadm_install_params.to_json_pretty}\n")

  wait_until_available(get_targets($peadm_target_list), wait_time => 300)

  # Once all the infrastructure data has been collected, handoff to puppetlabs/peadm
  run_plan('peadm::install', $params + $extra_peadm_params)

  $console = getvar('inventory.server.0.uri')
  out::message('Finished deployment of Puppet Enterprise')
  out::message("Log into Puppet Enterprise Console: https://${console}")
}
