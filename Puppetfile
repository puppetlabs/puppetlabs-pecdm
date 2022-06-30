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
    ref: '22a7ccbfcad6c8f4068b1d907824b096a71121e9'

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
    ref:          '651c95fb058d050476f496234ad97467b349d937',
    install_path: '.terraform'

mod 'terraform-aws_pe_arch',
    git:          'https://github.com/puppetlabs/terraform-aws-pe_arch.git',
    ref:          '9b6e8ae8aacfacb4046077c99f70da6b8f4dbf64',
    install_path: '.terraform'

mod 'terraform-azure_pe_arch',
    git:          'https://github.com/puppetlabs/terraform-azure-pe_arch.git',
    ref:          'cf2c482dd4311e55e287f9511b26e0c4ff99e6fc',
    install_path: '.terraform'
