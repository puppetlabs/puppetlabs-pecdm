# @summary Provision new PE cluster to The Cloud
#
plan pecdm::subplans::provision(
  Enum['xlarge', 'large', 'standard']           $architecture         = 'standard',
  Enum['development', 'production', 'user']     $cluster_profile      = 'development',
  Integer                                       $compiler_count       = 1,
  Optional[String[1]]                           $ssh_pub_key_file     = undef,
  Optional[Integer]                             $node_count           = undef,
  Optional[Variant[String[1],Hash]]             $instance_image       = undef,
  Optional[Variant[String[1],Array[String[1]]]] $subnet               = undef,
  Optional[String[1]]                           $subnet_project       = undef,
  Optional[Boolean]                             $disable_lb           = undef,
  Enum['private', 'public']                     $ssh_ip_mode          = 'public',
  Enum['private', 'public']                     $lb_ip_mode           = 'private',
  Array                                         $firewall_allow       = [],
  Hash                                          $extra_terraform_vars = {},
  Boolean                                       $replica              = false,
  # The final three parameters depend on the value of $provider, to do magic
  Enum['google', 'aws', 'azure']                $provider,
  String[1]                                     $project              = $provider ? { 'aws' => 'ape', default => undef },
  String[1]                                     $ssh_user             = $provider ? { 'aws' => 'ec2-user', default => undef },
  String[1]                                     $cloud_region         = $provider ? { 'azure' => 'westus2', 'aws' => 'us-west-2', default => 'us-west1' }
) {

  if $provider == 'google' {
    $_instance_image = $instance_image

    if $subnet.is_a(Array) {
      fail_plan('Google subnet must be provided as a String, an Array of subnets is only applicable for AWS based deployments')
    }
    if $lb_ip_mode == 'public' {
      fail_plan('Setting lb_ip_mode parameter to public with the GCP provider is not currently supported due to lack of GCP provided DNS')
    }
  }

  if $provider == 'aws' {
    $_instance_image = $instance_image

    if $subnet_project {
      fail_plan('Setting subnet_project parameter is only applicable for Google deployments using a subnet shared from another project')
    }
  }

  if $provider == 'azure' {
    if $instance_image.is_a(String) {
      $_instance_image = { 'instance_image' => $instance_image, 'image_plan' => '' }
    } else {
      $_instance_image = $instance_image
    }

    if $subnet {
      fail_plan('Azure provider does not currently support attachment to existing networks')
    }
  }

  # Where r10k deploys our various Terraform modules for each cloud provider
  $tf_dir = ".terraform/${provider}_pe_arch"

  # Ensure the Terraform project directory has been initialized ahead of
  # attempting an apply
  run_task('terraform::initialize', 'localhost', dir => $tf_dir)

  # Constructs a tfvars file to be used by Terraform
  $tfvars = epp('pecdm/tfvars.epp', {
    project              => $project,
    user                 => $ssh_user,
    lb_ip_mode           => $lb_ip_mode,
    ssh_key              => $ssh_pub_key_file,
    region               => $cloud_region,
    node_count           => $node_count,
    instance_image       => $_instance_image,
    subnet               => $subnet,
    subnet_project       => $subnet_project,
    firewall_allow       => $firewall_allow,
    architecture         => $architecture,
    cluster_profile      => $cluster_profile,
    replica              => $replica,
    compiler_count       => $compiler_count,
    disable_lb           => $disable_lb,
    extra_terraform_vars => $extra_terraform_vars
  })

  out::message("Starting infrastructure provisioning for a ${architecture} deployment of Puppet Enterprise")

  # TODO: make this print only when user specifies --verbose
  out::verbose(".tfvars file content:\n\n${tfvars}\n")

  # Creating an on-disk tfvars file to be used by Terraform::Apply to avoid a
  # shell escaping issue
  #
  # with_tempfile_containing() custom function suggestion by Cas is brilliant
  # for this, works perfectly
  $tf_apply = pecdm::with_tempfile_containing('', $tfvars, '.tfvars') |$tfvars_file| {
    # Stands up our cloud infrastructure that we'll install PE onto, returning a
    # specific set of data via TF outputs that if replicated will make this plan
    # easily adaptable for use with multiple cloud providers
    run_plan('terraform::apply',
      dir           => $tf_dir,
      return_output => true,
      var_file      => $tfvars_file
    )
  }

  # A pretty basic target config that just ensures we'll SSH into linux hosts
  # with a specific user and properly escalate to the root user
  $_target_config = {
    'config' => {
      'ssh' => {
        'user'           => $ssh_user,
        'host-key-check' => false,
        'run-as'         => 'root',
        'tty'            => true
      }
    }
  }

  $windows_runner_config = {
    'config' => {
      'ssh' => {
        'native-ssh'  => true,
        'ssh-command' => 'ssh' 
      }
    }
  }

  $target_config = pecdm::is_windows() ? {
    true  => deep_merge($_target_config, $windows_runner_config),
    false => $_target_config
  }

  # Generate an inventory of freshly provisioned nodes using the parameters that
  # are appropriate based on which cloud provider we've chosen to use. Utilizes
  # different name and uri parameters to allow for the target's SSH address to
  # differ from the names used to configure Puppet on the internal interfaces
  $inventory = ['server', 'psql', 'compiler', 'node'].reduce({}) |Hash $memo, String $i| {
    $memo + { $i => resolve_references( {
        '_plugin'        => 'terraform',
        'dir'            => $tf_dir,
        'resource_type'  => $provider ? {
          'google' => "google_compute_instance.${i}",
          'aws'    => "aws_instance.${i}",
          'azure'  => "azurerm_linux_virtual_machine.${i}",
        },
        'target_mapping' => $provider ? {
          'google' => {
            'name'         => 'metadata.internalDNS',
            'uri'          => $ssh_ip_mode ? {
              'private' => 'network_interface.0.network_ip',
              default   => 'network_interface.0.access_config.0.nat_ip',
            }
          },
          'aws' => {
            'name' => 'private_dns',
            'uri'  => $ssh_ip_mode ? {
              'private' => 'private_ip',
              default   => 'public_ip',
            }
          },
          'azure' => {
            'name' => 'tags.internalDNS',
            'uri'  => $ssh_ip_mode ? {
              'private' => 'private_ip_address',
              default   => 'public_ip_address',
            }
          }
        }
      })
    }
  }

  # Create Target objects from our previously generated inventory so that calls
  # to the get_target(s) function returns appropriate data
  $pecdm_targets = $inventory.map |$f, $v| { $v.map |$target| {
    Target.new($target.merge($target_config))
  } }.flatten

  $results = {
    'pe_inventory'          => $inventory.filter |$type, $values| { ($values.length > 0) and ($type != 'node') },
    'agent_inventory'       => $inventory['node'],
    'compiler_pool_address' => $tf_apply['pool']['value']
  }

  out::message("Finished provisioning infrastructure for a ${architecture} deployment of Puppet Enterprise")
  return $results
}
