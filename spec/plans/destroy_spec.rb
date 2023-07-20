require 'spec_helper'

describe 'pecdm::destroy' do
  include BoltSpec::Plans

  params = {
    'provider' => 'aws',
  }

  it 'destroy plan succeeds' do
    expect_plan('pecdm::subplans::destroy').be_called_times(1)
    expect(run_plan('pecdm::destroy', params)).to be_ok
  end
end
