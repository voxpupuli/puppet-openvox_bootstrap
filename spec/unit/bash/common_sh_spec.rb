# frozen_string_literal: true

require 'bash_spec_helper'

describe 'files/common.sh' do
  subject { 'files/common.sh' }

  include_context 'bash_prep'

  context 'logging' do
    let(:ts_regex) { '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' }

    it 'info()' do
      output, status = test('info "test"')

      expect(status.success?).to be(true)
      expect(output.strip).to match(%r{\A#{ts_regex} \[INFO\]: test\Z})
    end

    it 'err()' do
      output, status = test('err "test"')

      expect(status.success?).to be(true)
      expect(output.strip).to match(%r{\A#{ts_regex} \[ERROR\]: test\Z})
    end

    it 'fail()' do
      output, status = test('fail "test"')

      expect(status.success?).to be(false)
      expect(output.strip).to match(%r{\A#{ts_regex} \[ERROR\]: test\Z})
    end

    it 'assigned()' do
      output, status = test(<<~EOT)
        key='dingo'
        assigned key
      EOT

      expect(status.success?).to be(true)
      expect(output.strip).to match(%r{\A#{ts_regex} \[INFO\]: Assigned key=dingo\Z})
    end
  end

  context 'exists' do
    it 'returns 0 for existing command' do
      output, status = test('exists ruby')

      expect(status.success?).to be(true)
      expect(output).to be_empty
    end

    it 'returns non-zero for non-existing command' do
      output, status = test('exists doesnotexist')

      expect(status.success?).to be(false)
      expect(output).to be_empty
    end
  end

  context 'exec_and_capture' do
    before do
      allow_script.to receive_command(:date).and_exec('echo ts')
    end

    it 'executes a command, logging the output and returning the status' do
      output, status = test('exec_and_capture echo "hello world"')

      expect(status.success?).to be(true)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Executing: echo hello world
        hello world
        ts [INFO]: Status: 0
      EOS
    end

    it 'captures and returns a failing command' do
      output, status = test(<<~EOT)
        oops() {
          echo "oops"
          return 3
        }
        exec_and_capture oops
      EOT

      expect(status.exitstatus).to be(3)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Executing: oops
        oops
        ts [INFO]: Status: 3
      EOS
    end

    it 'captures stdout and stderr' do
      output, status = test(<<~EOT)
        something() {
          echo "stdout"
          echo "stderr" >&2
        }
        exec_and_capture something
      EOT

      expect(status.success?).to be(true)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Executing: something
        stdout
        stderr
        ts [INFO]: Status: 0
      EOS
    end

    it 'sets output and status variables' do
      output, status = test(<<~EOT)
        exec_and_capture echo dingo
        echo "LAST_EXEC_AND_CAPTURE_OUTPUT=$LAST_EXEC_AND_CAPTURE_OUTPUT"
        echo "LAST_EXEC_AND_CAPTURE_STATUS=$LAST_EXEC_AND_CAPTURE_STATUS"
      EOT

      expect(status.success?).to be(true)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Executing: echo dingo
        dingo
        ts [INFO]: Status: 0
        LAST_EXEC_AND_CAPTURE_OUTPUT=dingo
        LAST_EXEC_AND_CAPTURE_STATUS=0
      EOS
    end
  end

  context 'with_retries_if()' do
    before do
      allow_script.to receive_command(:date).and_exec('echo ts')
    end

    it 'executes a command' do
      output, status = test(<<~EOT)
        with_retries_if 3 1 '' echo "hello world"
      EOT

      expect(status.success?).to be(true)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Attempt 1 of 3: echo hello world
        ts [INFO]: Executing: echo hello world
        hello world
        ts [INFO]: Status: 0
      EOS
    end

    it 'can succeed after retries' do
      output, status = test(<<~"EOT")
        something_that_fails() {
          state_file="#{tmpdir}/state_file"
          if [ -e "$state_file" ]; then
            echo "success"
            return 0
          fi
          echo "something went oops"
          touch "$state_file"
          return 3
        }
        with_retries_if 3 0.1 'oops' something_that_fails
      EOT

      expect(status.success?).to be(true)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Attempt 1 of 3: something_that_fails
        ts [INFO]: Executing: something_that_fails
        something went oops
        ts [INFO]: Status: 3
        ts [INFO]: Retrying in 0.1 seconds...
        ts [INFO]: Attempt 2 of 3: something_that_fails
        ts [INFO]: Executing: something_that_fails
        success
        ts [INFO]: Status: 0
      EOS
    end

    it 'returns failure status if all attempts fail' do
      output, status = test(<<~EOT)
        something_that_fails() {
          echo "something went oops"
          return 1
        }
        with_retries_if 3 0.1 'oops' something_that_fails
      EOT

      expect(status.exitstatus).to eq(1)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Attempt 1 of 3: something_that_fails
        ts [INFO]: Executing: something_that_fails
        something went oops
        ts [INFO]: Status: 1
        ts [INFO]: Retrying in 0.1 seconds...
        ts [INFO]: Attempt 2 of 3: something_that_fails
        ts [INFO]: Executing: something_that_fails
        something went oops
        ts [INFO]: Status: 1
        ts [INFO]: Retrying in 0.1 seconds...
        ts [INFO]: Attempt 3 of 3: something_that_fails
        ts [INFO]: Executing: something_that_fails
        something went oops
        ts [INFO]: Status: 1
      EOS
    end

    it 'aborts if the command fails for another reason' do
      output, status = test(<<~EOT)
        something_that_fails() {
          echo "something went oops"
          return 1
        }
        with_retries_if 3 0.1 'error' something_that_fails
      EOT

      expect(status.exitstatus).to eq(1)
      expect(output).to eq(<<~EOS)
        ts [INFO]: Attempt 1 of 3: something_that_fails
        ts [INFO]: Executing: something_that_fails
        something went oops
        ts [INFO]: Status: 1
        ts [INFO]: Command failed but output did not match /error/. Aborting retries.
      EOS
    end
  end

  context 'download()' do
    context 'wget present', if: BashRspec.found(:wget) do
      it 'fails for 404' do
        output, status = test("download https://artifacts.voxpupuli.org/doesnotexist #{tmpdir}/file")

        expect(status.success?).to be(false)
        expect(output).to include('Executing: wget ')
        expect(output).to include('ERROR 404: Not Found.')
        file = File.read("#{tmpdir}/file")
        expect(file).to be_empty
      end
    end

    context 'curl present', if: BashRspec.found(:curl) do
      before do
        behave_as_if_command_does_not_exist(:wget)
      end

      it 'fails for 404' do
        output, status = test("download https://artifacts.voxpupuli.org/doesnotexist #{tmpdir}/file")

        expect(status.success?).to be(false)
        expect(output).to include('Executing: curl ')
        expect(output).to include('The requested URL returned error: 404')
        expect(File.exist?("#{tmpdir}/file")).to be(false)
      end
    end
  end

  context 'set_platform_globals()' do
    context 'successfully' do
      let(:os) { :ubuntu2404 }

      before do
        mock_facts_task_bash_sh(os)
      end

      it 'sets platform globals' do
        output, status = test('set_platform_globals')

        expect(status.success?).to be(true)
        expect(output).to include('Assigned platform=Ubuntu')
        expect(output).to include('Assigned os_full_version=24.04')
        expect(output).to include('Assigned os_major_version=24')
        expect(output).to include('Assigned os_family=ubuntu')
      end

      context 'with a pre-release' do
        let(:os) { :debian13 }

        it 'uses codename when release is n/a' do
          output, status = test('set_platform_globals')

          expect(status.success?).to be(true)
          expect(output).to include('Assigned platform=Debian')
          expect(output).to include('Assigned os_full_version=13')
          expect(output).to include('Assigned os_major_version=13')
          expect(output).to include('Assigned os_family=debian')
        end
      end
    end

    context 'fails' do
      it 'fails if it cannot find the facts script' do
        output, status = test('set_platform_globals')

        expect(status.success?).to be(false)
        expect(output).to include('Unable to find the puppetlabs-facts')
      end

      it 'fails for an unknown platform' do
        mock_facts_task_bash_sh(:unknown)

        output, status = test('set_platform_globals')

        expect(status.success?).to be(false)
        expect(output).to include("Unhandled platform: 'Unknown'")
      end
    end
  end

  context 'install_package()' do
    context 'ubuntu' do
      let(:os) { :ubuntu2404 }

      before do
        mock_facts_task_bash_sh(os)
        allow_script.to receive_command('apt-get').and_exec('echo "apt-get given: $*"')
      end

      it 'installs a package' do
        output, status = test('install_package foo')

        expect(output).to include('apt-get given: install -y foo')
        expect(status.success?).to be(true)
      end

      it 'installs a package with a version' do
        output, status = test('install_package foo 1.2.3')

        expect(status.success?).to be(true)
        expect(output).to include('apt-get given: install -y foo=1.2.3-1+ubuntu24.04')
      end

      it 'installs a deb with full package version given' do
        output, status = test('install_package foo 1.2.3-1something')

        expect(status.success?).to be(true)
        expect(output).to include('apt-get given: install -y foo=1.2.3-1something')
      end

      it 'fails if package manager fails' do
        allow_script.to receive_command('apt-get').and_exec(<<~EOF)
          echo 'apt-get failed'
          return 1
        EOF

        output, status = test('install_package doesnotexist')

        expect(status.success?).to be(false)
        expect(output).to include('apt-get failed')
      end

      it 'falls back to apt-get' do
        behave_as_if_command_does_not_exist('apt-get')
        allow_script.to receive_command(:apt).and_exec('echo "apt given: $*"')

        output, status = test('install_package foo')

        expect(status.success?).to be(true)
        expect(output).to include('apt given: install -y foo')
      end

      it 'fails if neither apt nor apt-get are available' do
        behave_as_if_command_does_not_exist(:apt)
        behave_as_if_command_does_not_exist('apt-get')

        output, status = test('install_package foo')

        expect(status.success?).to be(false)
        expect(output).to include('Neither apt nor apt-get are installed')
      end
    end

    context 'rocky' do
      let(:os) { :rocky9 }

      before do
        mock_facts_task_bash_sh(os)
        allow_script.to receive_command(:dnf).and_exec('echo "dnf given: $*"')
      end

      it 'installs a package' do
        output, status = test('install_package foo')

        expect(status.success?).to be(true)
        expect(output).to include('dnf given: install -y foo')
      end

      it 'installs a package with a version' do
        output, status = test('install_package foo 1.2.3')

        expect(status.success?).to be(true)
        expect(output).to include('dnf given: install -y foo-1.2.3')
      end

      it 'fails if package manager fails' do
        allow_script.to receive_command(:dnf).and_exec(<<~EOF)
          echo 'dnf failed'
          return 1
        EOF

        output, status = test('install_package doesnotexist')

        expect(status.success?).to be(false)
        expect(output).to include('dnf failed')
      end

      it 'falls back to yum' do
        behave_as_if_command_does_not_exist(:dnf)
        allow_script.to receive_command('yum').and_exec('echo "yum given: $*"')

        output, status = test('install_package foo')

        expect(status.success?).to be(true)
        expect(output).to include('yum given: install -y foo')
      end

      it 'fails if dnf, yum and zypper are all unavailable' do
        behave_as_if_command_does_not_exist(:dnf, :yum, :zypper)

        output, status = test('install_package foo')

        expect(status.success?).to be(false)
        expect(output).to include('Neither dnf, yum nor zypper are installed')
      end
    end
  end

  context 'noarch_package' do
    it 'returns 0 for a noarch package' do
      output, status = test('noarch_package openvox-server')

      expect(status.success?).to be(true)
      expect(output.strip).to be_empty
    end

    it 'returns 1 for a non-noarch package' do
      output, status = test('noarch_package foo')

      expect(status.success?).to be(false)
      expect(output.strip).to be_empty
    end
  end

  context 'set_cpu_architecture' do
    context 'debian or ubuntu' do
      it 'sets x86_64 for amd64' do
        allow_script.to receive_command(:uname).and_exec('echo x86_64')
        output, status = test('set_cpu_architecture debian')

        expect(status.success?).to be(true)
        expect(output).to include('Assigned cpu_arch=amd64')
      end

      it 'sets arm64 for aarch64' do
        allow_script.to receive_command(:uname).and_exec('echo aarch64')
        output, status = test('set_cpu_architecture ubuntu')

        expect(status.success?).to be(true)
        expect(output).to include('Assigned cpu_arch=arm64')
      end

      it 'sets amd64 for amd64' do
        allow_script.to receive_command(:uname).and_exec('echo amd64')
        output, status = test('set_cpu_architecture debian')

        expect(status.success?).to be(true)
        expect(output).to include('Assigned cpu_arch=amd64')
      end
    end

    context 'other' do
      it 'sets what uname gives it' do
        allow_script.to receive_command(:uname).and_exec('echo x86_64')
        output, status = test('set_cpu_architecture el')

        expect(status.success?).to be(true)
        expect(output).to include('Assigned cpu_arch=x86_64')
      end
    end
  end

  context 'set_package_architecture' do
    it 'sets all for debian noarch' do
      output, status = test('set_package_architecture openvox-server debian')

      expect(status.success?).to be(true)
      expect(output).to include('Assigned package_arch=all')
    end

    it 'sets noarch for el noarch' do
      output, status = test('set_package_architecture openvoxdb el')

      expect(status.success?).to be(true)
      expect(output).to include('Assigned package_arch=noarch')
    end

    it 'sets system arch otherwise' do
      allow_script.to receive_command(:uname).and_exec('echo x86_64')
      output, status = test('set_package_architecture openvox-agent el')

      expect(status.success?).to be(true)
      expect(output).to include('Assigned cpu_arch=x86_64')
      expect(output).to include('Assigned package_arch=x86_64')
    end
  end

  context 'set_artifacts_package_url' do
    context 'deb' do
      it 'builds a debian url' do
        allow_script.to set_env('os_family', 'debian')
        allow_script.to receive_command(:uname).and_exec('echo x86_64')
        output, status = test('set_artifacts_package_url https://foo openvox-agent 8.18.0')

        expect(status.success?).to be(true)
        package_name = 'openvox-agent_8.18.0-1%2Bdebian_amd64.deb'
        expect(output).to include("Assigned package_name=#{package_name}")
        expect(output).to include("Assigned package_url=https://foo/openvox-agent/8.18.0/#{package_name}")
      end

      it 'builds a noarch package url for ubuntu' do
        allow_script.to set_env('os_family', 'ubuntu')
        output, status = test('set_artifacts_package_url https://foo openvox-server 8.9.0')

        expect(status.success?).to be(true)
        package_name = 'openvox-server_8.9.0-1%2Bubuntu_all.deb'
        expect(output).to include("Assigned package_name=#{package_name}")
        expect(output).to include("Assigned package_url=https://foo/openvox-server/8.9.0/#{package_name}")
      end
    end

    context 'rpm' do
      it 'builds a redhat url' do
        allow_script.to set_env('os_family', 'el')
        allow_script.to receive_command(:uname).and_exec('echo x86_64')
        output, status = test('set_artifacts_package_url https://foo openvox-agent 8.18.0')

        expect(status.success?).to be(true)
        package_name = 'openvox-agent-8.18.0-1.el.x86_64.rpm'
        expect(output).to include("Assigned package_name=#{package_name}")
        expect(output).to include("Assigned package_url=https://foo/openvox-agent/8.18.0/#{package_name}")
      end

      it 'builds a noarch package url for redhat' do
        allow_script.to set_env('os_family', 'el')
        output, status = test('set_artifacts_package_url https://foo openvoxdb-termini 8.9.1')

        expect(status.success?).to be(true)
        package_name = 'openvoxdb-termini-8.9.1-1.el.noarch.rpm'
        expect(output).to include("Assigned package_name=#{package_name}")
        expect(output).to include("Assigned package_url=https://foo/openvoxdb/8.9.1/#{package_name}")
      end

      it 'builds a fedora url' do
        allow_script.to set_env('os_family', 'fedora')
        allow_script.to receive_command(:uname).and_exec('echo x86_64')
        output, status = test('set_artifacts_package_url https://foo openvox-agent 8.18.0')

        expect(status.success?).to be(true)
        package_name = 'openvox-agent-8.18.0-1.fc.x86_64.rpm'
        expect(output).to include("Assigned package_name=#{package_name}")
        expect(output).to include("Assigned package_url=https://foo/openvox-agent/8.18.0/#{package_name}")
      end
    end

    context 'pathing' do
      it 'looks for openvoxdb in the openvoxdb dir' do
        allow_script.to set_env('os_family', 'el')
        output, status = test('set_artifacts_package_url https://foo openvoxdb 8.9.1')

        expect(status.success?).to be(true)
        expect(output).to match(%r{Assigned package_url=https://foo/openvoxdb/8\.9\.1/})
      end

      it 'lookds for openvoxdb-termini in the openvoxdb dir as well' do
        allow_script.to set_env('os_family', 'el')
        output, status = test('set_artifacts_package_url https://foo openvoxdb-termini 8.9.1')

        expect(status.success?).to be(true)
        expect(output).to match(%r{Assigned package_url=https://foo/openvoxdb/8\.9\.1/})
      end
    end
  end

  context 'stop_and_disable_service' do
    it 'fails for an unknown package' do
      output, status = test('stop_and_disable_service unknown-package')

      expect(status.success?).to be(false)
      expect(output.strip).to include("Unknown service for package: 'unknown-package'")
    end

    it 'fails if puppet executable not found' do
      output, status = test('stop_and_disable_service openvox-agent /no/openvox')

      expect(status.success?).to be(false)
      expect(output.strip).to include("Puppet executable not found at '/no/openvox'")
    end

    context 'with puppet executable' do
      let(:mock_puppet) { "#{tmpdir}/puppet" }

      before do
        # The little BashRspec lib isn't sophisticated enough
        # to deal with an absolute path, so using this instead of
        # allow_script.to receive_command(mock_puppet)...
        File.write(mock_puppet, <<~EOF)
          #!/bin/sh
          echo "Stopping ${3} service"
        EOF
        File.chmod(0o755, mock_puppet)
      end

      [
        %w[openvox-agent puppet],
        %w[openvox-server puppetserver],
        %w[openvoxdb puppetdb],
      ].each do |package, service|
        it "stops the #{service} service for #{package}" do
          output, status = test("stop_and_disable_service #{package} #{mock_puppet}")

          expect(status.success?).to be(true)
          expect(output.strip).to include(service)
        end
      end
    end
  end
end
