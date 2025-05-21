# frozen_string_literal: true

require 'json'

# Mirrors the output from puppetlabs-facts.
module OBRspecFacts
  UBUNTU_2404 = {
    os: {
      name: 'Ubuntu',
      distro: {
        codename: 'noble',
      },
      release: {
        full: '24.04',
        major: '24',
        minor: '04',
      },
      family: 'Debian',
    },
  }.freeze

  DEBIAN_13 = {
    os: {
      name: 'Debian',
      distro: {
        codename: 'trixie',
      },
      release: {
        full: 'n/a',
        major: 'n/a',
        minor: '',
      },
      family: 'Debian',
    },
  }.freeze

  # This is a placeholder for an OS that openvox_bootstrap doesn't
  # know about yet, for testing failure cases.
  UNKNOWN = {
    os: {
      name: 'Unknown',
      distro: {
        codename: 'Mysterious Onions',
      },
      release: {
        full: '1000.99',
        major: '1000',
        minor: '99',
      },
      family: 'Unknown',
    },
  }.freeze

  FACTS = {
    ubuntu2404: UBUNTU_2404,
    debian13: DEBIAN_13,
    unknown: UNKNOWN,
  }.freeze

  def self.for(os)
    FACTS[os] || raise("Unknown OS: #{os}")
  end
end

RSpec.shared_context 'bash_prep' do
  let(:tmpdir) { Dir.mktmpdir }
  let(:bash_rspec_commands_that_do_not_exist) { [] }

  around do |example|
    example.run
  ensure
    FileUtils.remove_entry_secure tmpdir
  end

  def behave_as_if_command_does_not_exist(*commands)
    bash_rspec_commands_that_do_not_exist.concat(commands)
    # write, or overwrite definition with new set of commands
    allow_script.to(
      redeclare(:exists).as(
        <<~"EOF"
          case $1 in
            #{bash_rspec_commands_that_do_not_exist.join('|')})
              return 1
              ;;
            *)
              ;;
          esac
          original_exists $1
        EOF
      )
    )
  end

  # The facts/tasks/bash.sh from puppetlabs-facts is
  # sourced by the common.sh script, rooted from PT__installdir
  # as passed by Bolt.
  def mock_facts_task_bash_sh(os)
    allow_script.to set_env('PT__installdir', tmpdir)
    mocked_script_path = "#{tmpdir}/facts/tasks"
    facts = OBRspecFacts.for(os)
    FileUtils.mkdir_p(mocked_script_path)
    File.write("#{mocked_script_path}/bash.sh", <<~EOF)
      case $1 in
        platform)
          echo '#{facts.dig(:os, :name)}'
          ;;
        release)
          echo '#{facts.dig(:os, :release, :full)}'
          ;;
        *)
          echo '#{JSON.pretty_generate(facts)}'
          ;;
      esac
    EOF
  end
end
