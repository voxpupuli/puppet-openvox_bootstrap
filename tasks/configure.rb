#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../lib/openvox_bootstrap/task'
require 'etc'
require 'open3'
require 'yaml'

# rubocop:disable Style/NegatedIf
module OpenvoxBootstrap
  class Configure < Task
    def puppet_uid
      Etc.getpwnam('puppet').uid
    rescue ArgumentError
      nil
    end

    def puppet_gid
      Etc.getgrnam('puppet').gid
    rescue ArgumentError
      nil
    end

    def puppet_config_set(section, key, value)
      command = [
        '/opt/puppetlabs/bin/puppet',
        'config',
        'set',
        '--section', section,
        key,
        value,
      ]
      Open3.capture2e(*command)
    end

    # Add the given settings to the puppet.conf file using
    # puppet-config.
    #
    # Does nothing if given an empty or nil settings hash.
    #
    # @param settings [Hash<String,Hash<String,String>>]
    #   A hash of sections and settings to add to the
    #   puppet.conf file.
    # @return [Hash]
    def update_puppet_conf(settings, etc_puppet_path = '/etc/puppetlabs/puppet')
      return {} if settings.nil? || settings.empty?

      conf_path = File.join(etc_puppet_path, 'puppet.conf')
      success = true
      errors = {}
      settings.each do |section, section_settings|
        section_settings.each do |key, value|
          output, status = puppet_config_set(section, key, value)
          success &&= status.success?
          if !status.success?
            err_key = "--section=#{section} #{key}=#{value}"
            errors[err_key] = output
          end
        end
      end

      puppet_conf_contents = if File.exist?(conf_path)
                               File.read(conf_path)
                             else
                               ''
                             end

      result = {
        puppet_conf: {
          path: conf_path,
          contents: puppet_conf_contents,
          successful: success,
        }
      }
      result[:puppet_conf][:errors] = errors if !success
      result
    end

    # Overwrite the csr_attributes.yaml file with the given
    # csr_attributes hash.
    #
    # Does nothing if given an empty or nil csr_attributes.
    #
    # The file will be mode 640.
    # It will either be owned root:root (assuming task is run as root,
    # as expected), or puppet:puppet if the puppet user and group
    # exist (openvox-server package is installed).
    #
    # @param csr_attributes [Hash] A hash of custom_attributes
    #   and extension_requests to write to the csr_attributes.yaml
    #   file.
    # @return [Hash]
    def write_csr_attributes(csr_attributes, etc_puppet_path = '/etc/puppetlabs/puppet')
      return {} if csr_attributes.nil? || csr_attributes.empty?

      csr_attributes_path = File.join(etc_puppet_path, 'csr_attributes.yaml')
      csr_attributes_contents = csr_attributes.to_yaml
      File.open(csr_attributes_path, 'w', perm: 0o640) do |f|
        f.write(csr_attributes_contents)
      end
      # nil uid/gid are ignored by FileUtils.chown...
      File.chown(puppet_uid, puppet_gid, csr_attributes_path)

      {
        csr_attributes: {
          path: csr_attributes_path,
          contents: csr_attributes_contents,
          successful: true,
        }
      }
    end

    # Manage the puppet service using puppet apply.
    def manage_puppet_service(running, enabled)
      manifest = <<~MANIFEST
        service { 'puppet':
          ensure => #{running ? 'running' : 'stopped'},
          enable => #{enabled},
        }
      MANIFEST

      command = [
        '/opt/puppetlabs/bin/puppet',
        'apply',
        '--detailed-exitcodes',
        '-e',
        manifest.gsub(%r{\n}, ' ').strip,
      ]

      output, status = Open3.capture2e(*command)
      success = [0, 2].include?(status.exitstatus)

      {
        puppet_service: {
          command: command.join(' '),
          output: output,
          successful: success,
        }
      }
    end

    def task(
      puppet_conf: {},
      csr_attributes: {},
      puppet_service_running: true,
      puppet_service_enabled: true,
      **_kwargs
    )
      results = {}
      results.merge!(update_puppet_conf(puppet_conf))
      results.merge!(write_csr_attributes(csr_attributes))
      results.merge!(
        manage_puppet_service(puppet_service_running, puppet_service_enabled)
      )

      success = results.all? { |_, details| details[:successful] }

      if success
        results
      else
        puts JSON.pretty_generate(results)
        results.each do |config, details|
          next if details[:successful]

          puts "\nFailed managing #{config}:\n\n"
          puts details[:output] if details.key?(:output)
          pp details[:errors] if details.key?(:errors)
        end
        exit 1
      end
    end
  end
end
# rubocop:enable Style/NegatedIf

OpenvoxBootstrap::Configure.run if __FILE__ == $PROGRAM_NAME
