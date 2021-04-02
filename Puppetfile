forge 'https://forge.puppet.com'

# Modules from the Puppet Forge
mod 'puppetlabs-stdlib', '7.0.0'
mod 'puppetlabs-apply_helpers', '0.2.1'
mod 'puppetlabs-bolt_shim', '0.3.2'
mod 'puppetlabs-terraform', '0.6.1'

# Modules from Git
mod 'puppetlabs-peadm',
    git: 'https://github.com/puppetlabs/puppetlabs-peadm.git',
    ref: '985b8702f63dae664f983449dee17de01214bd0b'
mod 'puppet-node_manager',
    git: 'https://github.com/WhatsARanjit/puppet-node_manager.git',
    ref: '3775a9d07bdea9a9258225dc7053118b1f2fd871'

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
    ref:          '727e01f82e625d0d552f783b4dfc46a3b93ed46b',
    install_path: 'ext/terraform'

mod 'terraform-aws_pe_arch',
   git:          'https://github.com/puppetlabs/terraform-aws-pe_arch.git',
   ref:          'bac85d608436c940f59d74f5a94b194dbfbd2ef3',
   install_path: 'ext/terraform'
