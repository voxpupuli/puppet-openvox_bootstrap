# frozen_string_literal: true

require 'tmpdir'
require 'rspec'
require 'lib/bash_rspec'
require 'lib/contexts'

RSpec.configure do |c|
  c.include BashRspec
end
