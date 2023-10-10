forge 'https://forge.puppet.com'

mod 'puppetlabs-stdlib', '9.4.0'
mod 'puppetlabs-apply_helpers', '0.3.0'
mod 'puppetlabs-bolt_shim', '0.4.0'
mod 'puppetlabs-inifile', '6.1.0'
mod 'WhatsARanjit-node_manager', '0.8.0'
mod 'puppetlabs-ruby_task_helper', '0.6.1'
mod 'puppetlabs-ruby_plugin_helper', '0.2.0'
mod 'puppetlabs-peadm', '3.15.0'
mod 'puppetlabs-terraform', '0.7.0'

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
    ref:          'e3f9d5a65631373df061888f3aa8dec532461cf6',
    install_path: '.terraform'

mod 'terraform-azure_pe_arch',
    git:          'https://github.com/puppetlabs/terraform-azure-pe_arch.git',
    ref:          '0c362beddede71a83e10f76e873d85da01d9acea',
    install_path: '.terraform'
