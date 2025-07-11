# frozen_string_literal: true

require 'spec_helper'
require 'lib/contexts'
require 'openvox_bootstrap/task'

class OpenvoxBootstrap::TaskTester < OpenvoxBootstrap::Task
  def task(foo:, baz: 'default')
    {
      foo: foo,
      baz: baz,
    }
  end
end

describe 'openvox_bootstrap::task' do
  describe '.run' do
    include_context 'task_run_helpers'

    let(:input) { { foo: 'bar', baz: 'dingo' } }
    let(:expected_output) do
      {
        foo: 'bar',
        baz: 'dingo',
      }
    end
    let(:tester) { OpenvoxBootstrap::TaskTester }

    it 'raises for empty input' do
      expect do
        validate_task_run_for(tester, input: nil)
      end.to raise_error(ArgumentError)
    end

    it 'returns the task result' do
      validate_task_run_for(tester, input: input, expected: expected_output)
    end

    it 'uses default values for missing params' do
      input[:baz] = nil
      expected_output[:baz] = 'default'
      validate_task_run_for(tester, input: input, expected: expected_output)
    end
  end
end
