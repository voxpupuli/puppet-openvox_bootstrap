# frozen_string_literal: true

require 'json'

module OpenvoxBootstrap
  # Base class for openvox_bootstrap Ruby tasks.
  class Task
    # Run the task and print the result as JSON.
    def self.run
      params = JSON.parse($stdin.read)
      raise(ArgumentError, <<~ERR) unless params.is_a?(Hash)
        Expected a Hash, got #{params.class}: #{params.inspect}
      ERR

      params.transform_keys!(&:to_sym)
      # Clean out empty params so that task defaults are used.
      params.delete_if { |_, v| v.nil? || v == '' }

      result = new.task(**params)
      puts JSON.pretty_generate(result)

      result
    end
  end
end
