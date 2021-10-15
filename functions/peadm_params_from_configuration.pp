# Generate a parameters list to be fed to puppetlabs/peadm based on which
# architecture we've chosen to deploy. PEAdm will figure out the correct
# thing to do based on whether or not there are valid values for each
# architecture component. An empty array is equivalent to not defining the
# parameter.

function pecdm::peadm_params_from_configuration(
  Hash $inventory,
  String $compiler_pool_adress,
  String $version,
) >> Hash {
  {
    'primary_host'            => getvar('inventory.server.0.name'),
    'primary_postgresql_host' => getvar('inventory.psql.0.name'),
    'replica_host'            => getvar('inventory.server.1.name'),
    'replica_postgresql_host' => getvar('inventory.psql.1.name'),
    'compiler_hosts'          => getvar('inventory.compiler').map |$c| { $c['name'] },
    'dns_alt_names'           => [ 'puppet', $compiler_pool_adress ],
    'compiler_pool_address'   => $compiler_pool_adress,
    'download_mode'           => 'direct',
    'version'                 => $version
  }
}
