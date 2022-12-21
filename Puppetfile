forge 'https://forge.puppet.com'

# Modules from the Puppet Forge
mod 'puppetlabs-stdlib', '8.5.0'
mod 'puppetlabs-apply_helpers', '0.3.0'
mod 'puppetlabs-bolt_shim', '0.4.0'
mod 'puppetlabs-inifile', '5.4.0'
mod 'WhatsARanjit-node_manager', '0.7.5'
mod 'puppetlabs-ruby_task_helper', '0.6.1'
mod 'puppetlabs-ruby_plugin_helper', '0.2.0'

# Modules from Git
mod 'puppetlabs-peadm',
    git: 'https://github.com/puppetlabs/puppetlabs-peadm.git',
    ref: '67bfcfa1f255a28f19ca79fc4d4e696203bc32bb'
mod 'puppetlabs-terraform',
    git: 'https://github.com/puppetlabs/puppetlabs-terraform.git',
    ref: 'a57808f7477204681d27f6d7dee9b89bf714d9e7'

# External non-Puppet content
#
# Not a perfect solution given some assumptions made by r10k about repository
# naming, specifically that there can only be one "-" or "/" in the name and
# the component preceding those characters is dropped. These assumptions make
# using content from other tool that follow a different naming pattern
# sub-optimal but ultimately the on disk name and the name of the source
# repository are not required to match and naming is irrelevant to Bolt when the
# content is outside the modules and site-modules directories.
#
mod 'terraform-google_pe_arch',
    git:          'https://github.com/puppetlabs/terraform-google-pe_arch.git',
    ref:          '5772aebc633f72acb031d6c4b5f786e99a451a65',
    install_path: '.terraform'

mod 'terraform-aws_pe_arch',
    git:          'https://github.com/puppetlabs/terraform-aws-pe_arch.git',
    ref:          '0100d3145780eba8e9c96a07ef9c8ad74c61a959',
    install_path: '.terraform'

mod 'terraform-azure_pe_arch',
    git:          'https://github.com/puppetlabs/terraform-azure-pe_arch.git',
    ref:          '520e28c84a81d57f737d621534e5b2c5795c3983',
    install_path: '.terraform'
