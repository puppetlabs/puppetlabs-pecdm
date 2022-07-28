# @summary Destroy a pecdm provisioned PE cluster
#
plan pecdm::utils::deploy_agents(
  TargetSpec $targets,
  String     $primary_host,
  String     $compiler_pool_address = $primary_host,
) {

  out::message('Enrolling agent nodes into new Puppet Enterprise deployment')

  parallelize($targets) |$target| {
    run_task('peadm::agent_install', $target,
      'server' => $compiler_pool_address,
      'install_flags' => [
        '--puppet-service-ensure', 'stopped',
        "agent:certname=${target.name}",
      ],
    )

    run_task('peadm::submit_csr', $target)
  }

  run_task('peadm::sign_csr', peadm::get_targets($primary_host, 1),
    'certnames' => $targets.map |$a| { $a.name },
  )

  run_task('service', $targets,
    name   => 'puppet',
    action => 'start',
  )
}
