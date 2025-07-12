# frozen_string_literal: true

require 'spec_helper'
require 'lib/contexts'
require_relative '../../tasks/check'

describe 'openvox_bootstrap::check' do
  before do
    allow(OpenvoxBootstrap::Check).to receive(:puppet_version).and_return('8.0.0')
  end

  describe '.run' do
    include_context 'task_run_helpers'

    let(:input) do
      {
        version: nil
      }
    end
    let(:expected_output) do
      {
        puppet_version: '8.0.0',
        valid: true
      }
    end

    def validate_task_run(input:, expected:, code: 0)
      validate_task_run_for(OpenvoxBootstrap::Check, input: input, expected: expected, code: code)
    end

    it 'raises for empty input' do
      expect do
        validate_task_run(input: nil)
      end.to raise_error(ArgumentError)
    end

    it 'returns version without test if given no args' do
      validate_task_run(input: input, expected: expected_output)
    end

    context 'testing valid version' do
      it 'returns successfully' do
        input[:version] = '8.0.0'

        expected_output[:test] = 'eq'
        expected_output[:test_version] = '8.0.0'

        validate_task_run(input: input, expected: expected_output)
      end
    end

    context 'testing invalid version' do
      it 'returns non-zero' do
        input[:version] = '8.1.0'
        input[:test] = 'gt'

        expected_output[:valid] = false
        expected_output[:test] = 'gt'
        expected_output[:test_version] = '8.1.0'

        validate_task_run(input: input, expected: expected_output, code: 1)
      end
    end
  end

  describe '#task' do
    let(:check) { OpenvoxBootstrap::Check.new }

    context 'eq' do
      it 'returns true for equal versions' do
        expect(check.task(version: '8.0.0')).to(
          eq(
            {
              puppet_version: '8.0.0',
              valid: true,
              test: 'eq',
              test_version: '8.0.0'
            }
          )
        )
      end

      it 'returns false for unequal versions' do
        expect(check.task(version: '8.0.1')).to(
          eq(
            {
              puppet_version: '8.0.0',
              valid: false,
              test: 'eq',
              test_version: '8.0.1'
            }
          )
        )
      end
    end

    context 'ge' do
      it 'returns true for greater than versions' do
        expect(check.task(version: '7.0.0', test: 'ge')).to(
          eq(
            {
              puppet_version: '8.0.0',
              valid: true,
              test: 'ge',
              test_version: '7.0.0'
            }
          )
        )
      end

      it 'returns true for equal versions' do
        expect(check.task(version: '8.0.0', test: 'ge')).to(include(valid: true))
      end

      it 'returns false for less than versions' do
        expect(check.task(version: '9.0.0', test: 'ge')).to(
          eq(
            {
              puppet_version: '8.0.0',
              valid: false,
              test: 'ge',
              test_version: '9.0.0'
            }
          )
        )
      end
    end

    context 'gt' do
      it 'is valid for greater than versions' do
        expect(check.task(version: '7.0.0', test: 'gt')).to(include(valid: true))
      end

      it 'is invalid for equal versions or less than versions' do
        expect(check.task(version: '8.0.0', test: 'gt')).to(include(valid: false))
        expect(check.task(version: '8.0.1', test: 'gt')).to(include(valid: false))
      end
    end

    context 'lt' do
      it 'is valid for less than versions' do
        expect(check.task(version: '8.0.1', test: 'lt')).to(include(valid: true))
      end

      it 'is invalid for equal versions or greater than versions' do
        expect(check.task(version: '8.0.0', test: 'lt')).to(include(valid: false))
        expect(check.task(version: '7.0.0', test: 'lt')).to(include(valid: false))
      end
    end

    context 'le' do
      it 'is valid for less than or equal versions' do
        expect(check.task(version: '9.0.0', test: 'le')).to(include(valid: true))
        expect(check.task(version: '8.0.0', test: 'le')).to(include(valid: true))
      end

      it 'is invalid for greater than versions' do
        expect(check.task(version: '7.0.0', test: 'le')).to(include(valid: false))
      end
    end
  end
end
