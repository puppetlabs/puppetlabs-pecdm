forge 'https://forge.puppet.com'

# Modules from the Puppet Forge
mod 'puppetlabs-stdlib', '6.1.0'
mod 'WhatsARanjit-node_manager', '0.7.2'
mod 'puppetlabs-apply_helpers', '0.1.0'
mod 'puppetlabs-bolt_shim', '0.3.0'

# Modules from Git
mod 'puppetlabs-peadm',
    git: 'https://github.com/puppetlabs/puppetlabs-peadm.git',
    ref: 'main'
mod 'puppetlabs-terraform',
    git: 'https://github.com/puppetlabs/puppetlabs-terraform.git',
    ref: 'master'

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
    ref:          'main',
    install_path: 'ext/terraform'

mod 'terraform-aws_pe_arch',
   git:          'https://github.com/puppetlabs/terraform-aws-pe_arch.git',
   ref:          'master',
   install_path: 'ext/terraform'

