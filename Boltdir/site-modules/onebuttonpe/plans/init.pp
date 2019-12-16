plan onebuttonpe(
  TargetSpec $targets = get_targets('pe_adm_nodes')
) {

  $apply = run_plan('terraform::apply', 'dir' => 'terraform', return_output => true)

  $apply['infrastructure']['value'].each |$k,$v| { $v.each |$s| {
    Target.new({'name' => $s[0], 'uri' => $s[1]}).add_to_group('pe_adm_nodes')
  } }

  run_plan('peadm::provision', {
      'master_host'                    => $apply['infrastructure']['value']['masters'][0][0],
      'puppetdb_database_host'         => $apply['infrastructure']['value']['psql'][0][0],
      'master_replica_host'            => $apply['infrastructure']['value']['masters'][1][0],
      'puppetdb_database_replica_host' => $apply['infrastructure']['value']['psql'][1][0],
      'compiler_hosts'                 => $apply['infrastructure']['value']['compilers'].map |$c| { $c[0] },
      'console_password'               => "puppetlabs",
      'dns_alt_names'                  => [ "puppet",  $apply['console']['value'], $apply['pool']['value'] ],
      'compiler_pool_address'          => $apply['pool']['value'],
      'version'                        => "2019.2.2"
    }
  )
}
