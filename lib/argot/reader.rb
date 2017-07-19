if RUBY_PLATFORM =~ /java/
  require 'argot/jruby/reader'
else
  require 'argot/mri/reader'
end
