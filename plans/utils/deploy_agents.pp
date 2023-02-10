# @summary Deploy puppet agent and enroll a set of nodes into pecdm provisioned cluster
#
# @param compiler_pool_address
#   The FQDN that agent nodes will connect to for catalog compilation services
#
# @param primary_host
#   The target which is the cluster's primary node that is responsible for
#   certificate signing
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
        $target.transport ? {
          'winrm'  => '-PuppetServiceEnsure',
          default  => '--puppet-service-ensure'
        },
        'stopped',
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
