# frozen_string_literal: true

if RUBY_PLATFORM.match?(/java/)
  require 'argot/jruby/reader'
else
  require 'argot/mri/reader'
end
