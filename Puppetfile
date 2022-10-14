forge 'https://forge.puppet.com'

# Modules from the Puppet Forge
mod 'puppetlabs-stdlib', '8.1.0'
mod 'puppetlabs-apply_helpers', '0.3.0'
mod 'puppetlabs-bolt_shim', '0.4.0'
mod 'puppetlabs-terraform', '0.6.1'
mod 'puppetlabs-inifile', '5.2.0'
mod 'WhatsARanjit-node_manager', '0.7.5'

# Modules from Git
mod 'puppetlabs-peadm',
    git: 'https://github.com/puppetlabs/puppetlabs-peadm.git',
    ref: '57f5a9b38b2dbb17e3951b363a24ea9f41d9d464'

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
    ref:          '3c9b4c06c55ac95177d5fd3756c8fa9ee6fa45c0',
    install_path: '.terraform'

mod 'terraform-azure_pe_arch',
    git:          'https://github.com/puppetlabs/terraform-azure-pe_arch.git',
    ref:          '2c7e37f75ace3c50ad6622d6e2520c12ba3e23c6',
    install_path: '.terraform'
