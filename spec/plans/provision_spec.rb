require 'spec_helper'

describe 'pecdm::provision' do
  include BoltSpec::Plans

  params = {
    'provider' => 'aws',
    'console_password' => 'puppetlabs',
  }

  it 'provision plan succeeds' do
    allow_any_out_message
    allow_any_out_verbose
    expect_plan('pecdm::subplans::provision').be_called_times(1)
    expect_plan('pecdm::subplans::deploy').be_called_times(1)
    expect(run_plan('pecdm::provision', params)).to be_ok
  end
end
