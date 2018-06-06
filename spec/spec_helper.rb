$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'argot'
require 'util'

RSpec.configure do |c|
  c.include Util
  c.extend Util::Extend
end
