#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../lib/openvox_bootstrap/task'

module OpenvoxBootstrap
  class Check < Task
    # Get the Puppet version from the installed Puppet library.
    #
    # "require 'puppet/version'" can be fooled by the Ruby environment
    # if the gem is installed. For example:
    #
    #   bolt task run openvox_bootstrap::check --targets localhost
    #
    # will be executed using the bolt package's Ruby environment,
    # which includes a puppet gem that will mostly likely be out of
    # sync with the installed Puppet version.
    def self.puppet_version
      require '/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/version'
      Puppet.version
    end

    # Run the task and print the result as JSON.
    def self.run
      result = super
      result[:valid] ? exit(0) : exit(1)
    end

    def task(version: nil, test: 'eq', **_kwargs)
      puppet_version = Gem::Version.new(OpenvoxBootstrap::Check.puppet_version)
      result = {
        puppet_version: puppet_version.to_s,
      }
      result[:valid] = if version.nil? || version.empty?
                         true
                       else
                         test_version = Gem::Version.new(version)
                         result[:test] = test
                         result[:test_version] = version
                         case test
                         when 'eq'
                           puppet_version == test_version
                         when 'lt'
                           puppet_version < test_version
                         when 'le'
                           puppet_version <= test_version
                         when 'gt'
                           puppet_version > test_version
                         when 'ge'
                           puppet_version >= test_version
                         else
                           raise ArgumentError, "Unknown test: '#{test}'"
                         end
                       end

      result
    end
  end
end

OpenvoxBootstrap::Check.run if __FILE__ == $PROGRAM_NAME
