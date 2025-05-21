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
        file = File.read("#{tmpdir}/file")
        expect(file).to include('404 Not Found')
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
        output, status = test(<<~EOT)
          set_platform_globals
          echo "set platform=$platform"
          echo "set os_full_version=$os_full_version"
          echo "set os_major_version=$os_major_version"
          echo "set os_family=$os_family"
        EOT

        expect(status.success?).to be(true)
        expect(output).to include('set platform=Ubuntu')
        expect(output).to include('set os_full_version=24.04')
        expect(output).to include('set os_major_version=24')
        expect(output).to include('set os_family=ubuntu')
      end

      context 'with a pre-release' do
        let(:os) { :debian13 }

        it 'uses codename when release is n/a' do
          output, status = test(<<~EOT)
            set_platform_globals
            echo "set platform=$platform"
            echo "set os_full_version=$os_full_version"
            echo "set os_major_version=$os_major_version"
            echo "set os_family=$os_family"
          EOT

          expect(status.success?).to be(true)
          expect(output).to include('set platform=Debian')
          expect(output).to include('set os_full_version=13')
          expect(output).to include('set os_major_version=13')
          expect(output).to include('set os_family=debian')
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

        output, status = test(<<~EOT)
          set_platform_globals
          echo "set platform=$platform"
          echo "set os_full_version=$os_full_version"
          echo "set os_major_version=$os_major_version"
          echo "set os_family=$os_family"
        EOT

        expect(status.success?).to be(false)
        expect(output).to include("Unhandled platform: 'Unknown'")
      end
    end
  end
end
