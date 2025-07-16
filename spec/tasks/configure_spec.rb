# frozen_string_literal: true

require 'spec_helper'
require_relative '../../tasks/configure'

# rubocop:disable RSpec/MessageSpies
# rubocop:disable RSpec/StubbedMock
describe 'openvox_bootstrap::configure' do
  let(:tmpdir) { Dir.mktmpdir('openvox_bootstrap-configure-spec') }
  let(:task) { OpenvoxBootstrap::Configure.new }

  around do |example|
    example.run
  ensure
    FileUtils.remove_entry_secure(tmpdir)
  end

  describe '#write_puppet_conf' do
    let(:puppet_conf) do
      {
        'main' => {
          'server'   => 'puppet.spec',
          'certname' => 'agent.spec',
        },
        'agent' => {
          'environment' => 'test'
        }
      }
    end
    let(:puppet_conf_path) { File.join(tmpdir, 'puppet.conf') }
    let(:puppet_conf_contents) do
      <<~CONF
        [main]
        server = puppet.spec
        certname = agent.spec

        [agent]
        environment = test
      CONF
    end

    it 'writes a puppet.conf ini' do
      expect(task.write_puppet_conf(puppet_conf, tmpdir)).to(
        eq(
          {
            puppet_conf: {
              path: puppet_conf_path,
              contents: puppet_conf_contents
            }
          }
        )
      )
      expect(File.read(puppet_conf_path)).to eq(puppet_conf_contents)
    end

    it 'does nothing if given an empty config' do
      expect(task.write_puppet_conf(nil)).to eq({})
      expect(task.write_puppet_conf({})).to eq({})
    end
  end

  def check_returned_id(uid_or_gid)
    case uid_or_gid
    when Integer
      uid_or_gid > 0
    when nil
      true # If the user does not exist, it returns nil.
    else
      false # Should not return anything else.
    end
  end

  describe '#puppet_uid' do
    it 'returns the UID of the puppet user' do
      expect(task.puppet_uid).to satisfy do |uid|
        check_returned_id(uid)
      end
    end
  end

  describe '#puppet_gid' do
    it 'returns the GID of the puppet group' do
      expect(task.puppet_gid).to satisfy do |gid|
        check_returned_id(gid)
      end
    end
  end

  describe '#write_csr_attributes' do
    let(:csr_attributes) do
      {
        'custom_attributes' => {
          '1.2.840.113549.1.9.7' => 'bar',
        },
        'extension_requests' => {
          'pp_role' => 'spec'
        }
      }
    end
    let(:csr_attributes_path) { File.join(tmpdir, 'csr_attributes.yaml') }
    let(:csr_attributes_contents) do
      <<~YAML
        ---
        custom_attributes:
          1.2.840.113549.1.9.7: bar
        extension_requests:
          pp_role: spec
      YAML
    end

    it 'writes a csr_attributes.yaml file' do
      expect(task.write_csr_attributes(csr_attributes, tmpdir)).to(
        eq(
          {
            csr_attributes: {
              path: csr_attributes_path,
              contents: csr_attributes_contents,
            }
          }
        )
      )
      expect(File.read(csr_attributes_path)).to eq(csr_attributes_contents)
      expect(File.stat(csr_attributes_path).mode & 0o777).to eq(0o640)
    end

    it 'does nothing if given an empty config' do
      expect(task.write_csr_attributes(nil)).to eq({})
      expect(task.write_csr_attributes({})).to eq({})
    end
  end

  describe '#manage_puppet_service' do
    def status(code = 0)
      instance_double(Process::Status, exitstatus: code)
    end

    it 'is successful for a 0 exit code' do
      command = [
        '/opt/puppetlabs/bin/puppet',
        'apply',
        '--detailed-exitcodes',
        '-e',
        %(service { 'puppet':   ensure => running,   enable => true, }),
      ]
      expect(Open3).to receive(:capture2e).with(*command).and_return(['applied', status])

      expect(task.manage_puppet_service(true, true)).to eq(
        {
          puppet_service: {
            command: command.join(' '),
            output: 'applied',
            successful: true,
          }
        }
      )
    end

    it 'is successful for a 2 exit code' do
      expect(Open3).to receive(:capture2e).and_return(['applied', status(2)])

      result = task.manage_puppet_service(true, true)
      expect(result.dig(:puppet_service, :successful)).to be true
    end

    it 'fails for a non 0, 2 exit code' do
      expect(Open3).to receive(:capture2e).and_return(['applied', status(1)])

      result = task.manage_puppet_service(true, true)
      expect(result.dig(:puppet_service, :successful)).to be false
    end
  end

  describe '#task' do
    it 'returns a result hash if puppet service is managed successfully' do
      expect(task).to receive(:manage_puppet_service).and_return({ puppet_service: { successful: true } })

      expect(task.task).to eq(
        {
          puppet_service: { successful: true },
        }
      )
    end

    it 'prints results and exits 1 if puppet service fails' do
      expect(task).to(
        receive(:manage_puppet_service).
        and_return(
          {
            puppet_service: {
              successful: false,
              output: "apply failed\n",
            }
          }
        )
      )

      expect { task.task }.to(
        raise_error(SystemExit).and(
          output(<<~EOM).to_stdout
            {
              "puppet_service": {
                "successful": false,
                "output": "apply failed\\n"
              }
            }

            Failed managing the puppet service:

            apply failed
          EOM
        ).and(output('').to_stderr)
      )
    end
  end
end
# rubocop:enable RSpec/MessageSpies
# rubocop:enable RSpec/StubbedMock
