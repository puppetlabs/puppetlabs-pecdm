require 'spec_helper'
require 'bolt/target'
require 'bolt/inventory'
require 'bolt/plugin'

describe 'pecdm::upgrade' do
  include BoltSpec::Plans

  params = {
    'provider' => 'aws',
  }

  let(:target_data) { { 'name' => 'my-target', 'uri' => 'ssh://my-target' } }
  # let(:inventory) { instance_double(Bolt::Inventory::Inventory).as_null_object }
  let(:inventory) { instance_double(Bolt::Inventory::Inventory) }
  let(:target) { Bolt::Target.new('my-target', inventory) }
  let(:plugin) { instance_double('Plugin') }

  before :each do
    allow(plugin).to receive(:resolve_references).and_return([target_data])
    allow(inventory).to receive(:get_targets).and_return([target])
    allow(inventory).to receive(:targets).and_return([target])
    allow(inventory).to receive(:target_implementation_class).with(no_args).and_return(Bolt::Target)
    allow(inventory).to receive(:version).and_return(2)
    allow(inventory).to receive(:create_target_from_hash).and_return(target)
    allow(inventory).to receive(:plugins).and_return(plugin)
    allow(inventory).to receive(:add_to_group)
    # allow_any_instance_of(Bolt::PAL::YamlPlan::Evaluator).to receive(:resolve_references).and_return([target])
    Bolt::Logger.configure({ 'console' => { 'level' => 'trace' } }, true)
  end

  it 'upgrade plan succeeds' do
    puts "Inventory: #{inventory.inspect}"
    allow_any_out_message
    allow_task('peadm::get_peadm_config').be_called_times(1)
    allow_plan('peadm::upgrade').be_called_times(1)
    expect(run_plan('pecdm::upgrade', params)).to be_ok
  end
end
