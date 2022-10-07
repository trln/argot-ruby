# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'argot'
require 'util'
require 'pry'

RSpec.configure do |c|
  c.include Util
  c.extend Util::Extend
end
