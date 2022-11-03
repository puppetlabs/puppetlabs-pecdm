# @summary Provision required infrastructure in the cloud to support a specific Puppet Enterprise architecture
#
# @param architecture
#   Which of the three supported architectures to provision infrastructure for
#
# @param cluster_profile
#   The profile of the cluster provisioned that determines if it is more suited
#   for development or production
#
# @param compiler_count
#   Quantity of compilers that are provisioned and deployed in Large and Extra
#   Large installations
#
# @param ssh_pub_key_file
#   Path to the ssh public key file that will be passed to Terraform for
#   granting access to instances over SSH
#
# @param node_count
#   Number of Linux agent nodes to provision and enroll into deployment for testing
#   and development
#
# @param instance_image
#   The cloud image that is used for new instance provisioning, format differs
#   depending on provider
#
# @param windows_node_count
#   Number of Windows agent nodes to provision and enroll into deployment for testing
#   and development
#
# @param windows_instance_image
#   The cloud image that is used for new Windows instance provisioning, format differs
#   depending on provider
#
# @param windows_user
#   The adminstrative user account created on Windows nodes nodes allowing for WINRM connections
#
# @param windows_password
#   The adminstrative user account password on Windows nodes nodes allowing for WINRM connections
#
# @param subnet
#   Name or ID of an existing subnet to attach newly provisioned infrastructure
#   to
#
# @param subnet_project
#   If using the GCP provider, the name of the project which owns the existing
#   subnet you are attaching new infrastructure to if it is different than the
#   project you are provisioning into
#
# @param disable_lb
#   Option to disable load balancer creation for situations where you're
#   required to leverage alternate technology than what is provided by the cloud
#   provider
#
# @param ssh_ip_mode
#   The type of IPv4 address that will be used to gain SSH access to instances
#
# @param lb_ip_mode
#   The type of IPv4 address that is used for load balancing, private or public
#
# @param firewall_allow
#   IPv4 address subnets that should have access to PE through firewall
#
# @param extra_terraform_vars
#   The pecdm plan does not expose all variables defined by supporting Terraform
#   modules, if others are needed then pass a hash
#
# @param replica
#   Set to true to deploy a replica and enable PE DR for any of the three
#   supported architectures
#
# @param provider
#   Which cloud provider that infrastructure will be provisioned into
#
# @param project
#   One of three things depending on the provider used: a GCP project to deploy
#   infrastructure into, the name of the Azure resource group that is created
#   specifically for new infrastructure, or a simple tag attached to AWS
#   instances
#
# @param ssh_user
#   User name that will be used for accessing infrastructure over SSH, defaults
#   to ec2-user on when using the AWS provider but a value is required on GCp and Azure
#
# @param cloud_region
#   Which region to provision infrastructure in, if not provided default will
#   be determined by provider
#
# @param native_ssh
#   Set this to true if the plan should leverage native SSH instead of Ruby's
#   net-ssh library
#
plan pecdm::subplans::provision(
  Enum['xlarge', 'large', 'standard']           $architecture           = 'standard',
  Enum['development', 'production', 'user']     $cluster_profile        = 'development',
  Integer                                       $compiler_count         = 1,
  Optional[String[1]]                           $ssh_pub_key_file       = undef,
  Optional[Integer]                             $node_count             = undef,
  Optional[Variant[String[1],Hash]]             $instance_image         = undef,
  Optional[Integer]                             $windows_node_count     = undef,
  Optional[Variant[String[1],Hash]]             $windows_instance_image = undef,
  Optional[String[1]]                           $windows_user           = 'windows',
  Optional[Sensitive[String[1]]]                $windows_password,
  Optional[Variant[String[1],Array[String[1]]]] $subnet                 = undef,
  Optional[String[1]]                           $subnet_project         = undef,
  Optional[Boolean]                             $disable_lb             = undef,
  Enum['private', 'public']                     $ssh_ip_mode            = 'public',
  Enum['private', 'public']                     $lb_ip_mode             = 'private',
  Array                                         $firewall_allow         = [],
  Hash                                          $extra_terraform_vars   = {},
  Boolean                                       $replica                = false,
  Boolean                                       $native_ssh             = false,
  # The final three parameters depend on the value of $provider, to do magic
  Enum['google', 'aws', 'azure']                $provider,
  String[1]                                     $project                = $provider ? { 'aws' => 'pecdm', default => undef },
  String[1]                                     $ssh_user               = $provider ? { 'aws' => 'ec2-user', default => undef },
  String[1]                                     $cloud_region           = $provider ? { 'azure' => 'westus2', 'aws' => 'us-west-2', default => 'us-west1' }
) {
  if $provider == 'google' {
    $_instance_image = $instance_image
    $_windows_instance_image = undef #$instance_image when google windows client enabled

    if $subnet.is_a(Array) {
      fail_plan('Google subnet must be provided as a String, an Array of subnets is only applicable for AWS based deployments')
    }
    if $lb_ip_mode == 'public' {
      fail_plan('Setting lb_ip_mode parameter to public with the GCP provider is not currently supported due to lack of GCP provided DNS')
    }
  }

  if $provider == 'aws' {
    $_instance_image = $instance_image
    $_windows_instance_image = undef #$instance_image when aws windows client enabled

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
    if $windows_instance_image.is_a(String) {
      $_windows_instance_image = { 'windows_instance_image' => $windows_instance_image, 'image_plan' => '' }
    } else {
      $_windows_instance_image = $instance_image
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
    project                => $project,
    user                   => $ssh_user,
    windows_user           => $windows_user,
    lb_ip_mode             => $lb_ip_mode,
    ssh_key                => $ssh_pub_key_file,
    region                 => $cloud_region,
    node_count             => $node_count,
    instance_image         => $_instance_image,
    windows_node_count     => $windows_node_count,
    windows_instance_image => $_windows_instance_image,
    windows_password       => $windows_password.unwrap,
    subnet                 => $subnet,
    subnet_project         => $subnet_project,
    firewall_allow         => $firewall_allow,
    architecture           => $architecture,
    cluster_profile        => $cluster_profile,
    replica                => $replica,
    compiler_count         => $compiler_count,
    disable_lb             => $disable_lb,
    provider               => $provider,
    extra_terraform_vars   => $extra_terraform_vars
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

  $native_ssh_config = {
    'config' => {
      'ssh' => {
        'native-ssh'  => true,
        'ssh-command' => 'ssh'
      }
    }
  }

  $target_config = $native_ssh ? {
    true  => deep_merge($_target_config, $native_ssh_config),
    false => $_target_config
  }

  $windows_target_config = {
    'config' => {
      'transport' => 'winrm',
        'winrm' => {
        'user' => $windows_user,
        'password' => $windows_password.unwrap,
        'ssl' => false,
        'connect-timeout' => 30,
        },
      },
    }

  # Generate an inventory of freshly provisioned nodes using the parameters that
  # are appropriate based on which cloud provider we've chosen to use. Utilizes
  # different name and uri parameters to allow for the target's SSH address to
  # differ from the names used to configure Puppet on the internal interfaces
  $inventory = ['server', 'psql', 'compiler', 'node', 'windows_node'].reduce({}) |Hash $memo, String $i| {
    $memo + { $i => resolve_references( {
        '_plugin'        => 'terraform',
        'dir'            => $tf_dir,
        'resource_type'  => $provider ? {
          'google' => "google_compute_instance.${i}",
          'aws'    => "aws_instance.${i}",
          'azure'  => $i ? {
            'windows_node' => "azurerm_windows_virtual_machine.${i}",
            default        => "azurerm_linux_virtual_machine.${i}",
        },
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
    if $f == 'windows_node' {
    Target.new($target.merge($windows_target_config))
    } else {
    Target.new($target.merge($target_config))
    }
  } }.flatten

  $results = {
    'pe_inventory'            => $inventory.filter |$type, $values| { ($values.length > 0) and ($type != 'node' and $type != 'windows_node') },
    'agent_inventory'         => $inventory['node'],
    'windows_agent_inventory' => $inventory['windows_node'],
    'compiler_pool_address'   => $tf_apply['pool']['value']
  }

  out::message("Finished provisioning infrastructure for a ${architecture} deployment of Puppet Enterprise")
  return $results
}
