if RUBY_PLATFORM =~ /java/
    require 'argot/jruby/reader'
else
    require 'argot/mri/reader'
end
require 'argot/pipeline'
require 'argot/flattener'
require 'argot/suffixer'
require 'argot/validator'
module Argot
    
end
