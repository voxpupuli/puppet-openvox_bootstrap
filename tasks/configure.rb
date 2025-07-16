#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../lib/openvox_bootstrap/task'
require 'etc'
require 'open3'
require 'yaml'

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

    # Overwrite puppet.conf with the values in the puppet_conf hash.
    #
    # Does nothing if given an empty or nil puppet_conf.
    #
    # @param puppet_conf [Hash<String,Hash<String,String>>] A hash of
    #   sections and settings to write to the puppet.conf file.
    # @return [Hash]
    def write_puppet_conf(puppet_conf, etc_puppet_path = '/etc/puppetlabs/puppet')
      return {} if puppet_conf.nil? || puppet_conf.empty?

      conf_path = File.join(etc_puppet_path, 'puppet.conf')
      sections = puppet_conf.map do |section, settings|
        "[#{section}]\n" +
          settings.map { |key, value| "#{key} = #{value}" }.join("\n")
      end
      puppet_conf_contents = "#{sections.join("\n\n")}\n"

      File.open(conf_path, 'w', perm: 0o644) do |f|
        f.write(puppet_conf_contents)
      end

      {
        puppet_conf: {
          path: conf_path,
          contents: puppet_conf_contents,
        }
      }
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
      puppet_conf_result = write_puppet_conf(puppet_conf)
      csr_result = write_csr_attributes(csr_attributes)
      puppet_service_result = manage_puppet_service(puppet_service_running, puppet_service_enabled)

      results = puppet_conf_result.merge(
        csr_result
      ).merge(puppet_service_result)

      success = results[:puppet_service][:successful]
      if success
        results
      else
        puts JSON.pretty_generate(results)
        puts "\nFailed managing the puppet service:\n\n"
        puts results[:puppet_service][:output]
        exit 1
      end
    end
  end
end

OpenvoxBootstrap::Configure.run if __FILE__ == $PROGRAM_NAME
