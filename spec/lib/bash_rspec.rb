# frozen_string_literal: true

require 'mkmf'
require 'open3'

# Simple harness for testing libraries of BASH shell functions within
# the RSpec framework.
#
# This module provides a simple DSL for mocking system commands
# and functions in a given script. It also provides a way to
# generate a test script that sources the given script and
# then executes a command for evaluation.
#
# The module assumes that the the file under test is located within
# the repository, may be sourced as a library of bash functions
# without side-effects, and that the file under test has been set via:
#
#     subject { 'path/to/file.sh' }
#
# # Usage
#
# ## Testing a function
#
# The test() function returns Open3.capture2e() output and status:
#
#     it 'tests execution of something()' do
#       output, status = test("something")
#       expect(status.success?).to be(true)
#       expect(output).to include('something exciting')
#     end
#
# ## Mocking a command
#
# The receive_command() method may be used to mock a command:
#
#     it 'tests execution of something() but without boom' do
#       allow_script.to receive_command(:boom).and_exec(<<~"EOF")
#         echo "pretend we did something destructive instead"
#       EOF
#       output, status = test("something_that_goes_boom_inside")
#       expect(status.success?).to be(true)
#       expect(output).to include('something exciting without as much boom')
#     end
#
# ## Redeclaring a BASH function
#
# The redeclare() method may be used to replace a BASH function while
# allowing you to call the original function:
#
#     it 'tests execution of something() but with modified other()' do
#        allow_script.to redeclare(:other).and_exec(<<~"EOF")
#          echo "do something first"
#          original_other $@
#        EOF
#        output, status = test("something")
#        expect(status.success?).to be(true)
#        expect(output).to include('something exciting')
#     end
#
# ## Setting environment variables
#
# The set_env() method may be used to set environment variables that
# the script may need for execution:
#
#     it 'tests execution of something() with a custom env var' do
#       allow_script.to set_env('SOME_VAR', 'some_value')
#       output, status = test("echo $SOME_VAR")
#       expect(status.success?).to be(true)
#       expect(output).to eq('some_value')
#     end
#
# All of the condition behavior defined above are keyed by the name of
# the command, function or variable. Multiple calls with the same key
# only redefine the behavior to the last call.
module BashRspec
  # Test whether a command is available on the system.
  def self.found(command)
    # from stdlib mkmf gem
    find_executable(command.to_s)
  end

  # Encapsulates replaced behavior for 'receive_command'.
  class CommandMock
    # The command to be mocked.
    attr_reader :command
    # The behavior to be executed in place of the command.
    attr_reader :behavior

    def initialize(command)
      @command = command
    end

    def and_exec(behavior)
      @behavior = behavior
      self
    end

    def indented_behavior
      behavior.split("\n").map do |line|
        line.sub(%r{^}, '  ')
      end.join("\n")
    end

    def generate
      <<~"EOF"
        function #{command}() {
        #{indented_behavior}
        }
      EOF
    end
  end

  # Encapsulates replaced behavior for 'redeclare' of a BASH function.
  class FunctionMock < CommandMock
    alias as and_exec

    def generate
      <<~"EOF"
        eval "original_$(declare -f #{command})"

        #{super}
      EOF
    end
  end

  # Simple class to encapsulate environment variables that should
  # be set prior to sourcing the script under test.
  class EnvVar
    attr_reader :name, :value

    def initialize(name, value)
      @name = name
      @value = value
    end

    def generate
      %(#{name}="#{value}")
    end
  end

  # Keeps track of the set of mocks for a given script.
  class ScriptMocker
    # The script file to be mocked.
    attr_reader :script
    # The set of CommandMock instances for the script.
    attr_reader :mocks
    # The set of EnvVar instances to set for the script.
    attr_reader :env_vars

    def initialize(script)
      @script = script
      @mocks = {}
      @env_vars = {}
    end

    def to(condition)
      case condition
      when CommandMock
        mocks[condition.command.to_sym] = condition
      when EnvVar
        env_vars[condition.name.to_sym] = condition
      else
        raise(ArgumentError, "BashRspec doesn't know what to do with condition: #{condition}")
      end
      self
    end

    # Concatenates the set of CommandMock#behavior for the given script.
    def generate(type)
      header = case type
               when :mocks
                 'mock commands'
               when :env_vars
                 'environment variables'
               else
                 raise(ArgumentError, "BashRspec doesn't know how to generate #{type}")
               end
      conditions = send(type).values
      code = conditions.map(&:generate).join("\n")
      <<~EOS
        # #{header}
        #{code}
      EOS
    end
  end

  # Returns (and creates and caches) a ScriptMocker instance
  # for the given script within the current Rspec test context.
  def lookup(script)
    @scripts ||= {}
    @scripts[script] ||= ScriptMocker.new(script)
  end

  def module_root
    File.expand_path(File.join(__dir__, '..', '..'))
  end

  # Mock a system command.
  def receive_command(command)
    CommandMock.new(command)
  end

  # Redeclare a Bash function as original_${function}()
  # in order to replace it with a mock that can access
  # it's original behavior.
  def redeclare(function)
    FunctionMock.new(function)
  end

  # Set an environment variable for the script being tested.
  def set_env(name, value)
    EnvVar.new(name, value)
  end

  # Begins an rspec-mocks style interface for mocking commands
  # in a given script file.
  def allow_script(script = subject)
    lookup(script)
  end

  # Assembly of everything needed to run a test.
  # (Also useful for debugging.)
  def script_harness(script = subject)
    sm = lookup(script)
    <<~SCRIPT
      #{sm.generate(:env_vars)}

      # source under test
      source "${MODULE_ROOT}/#{script}"

      #{sm.generate(:mocks)}
    SCRIPT
  end

  # Run a command scriptlet in the context of the script under test.
  def test(command, script: subject)
    test_script = <<~SCRIPT
      #{script_harness(script)}

      # test code
      #{command}
    SCRIPT
    Open3.capture2e({ 'MODULE_ROOT' => module_root }, 'bash', '-c', test_script)
  end
end
