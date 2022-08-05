require 'facter'
Puppet::Functions.create_function(:'pecdm::is_windows') do
  def is_windows()
    Facter.value('os.name') == 'windows'
  end
end
