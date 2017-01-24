##
# Argot -- tools for working with TRLN shared record format.
# +require+-ing this module also imports the +Argot::Validator+ and +Argot::Reader+ classes.
# 
# Other tools and utilities that are available
# {+Argot::TrajectJSONWriter+}[rdoc-ref:Argot::TrajectJSONWriter] (+require 'argot/traject_writer'+) - a Traject Writer implementation that converts the usual Traject output format more friendly 
require 'argot/validator'

if RUBY_PLATFORM =~ /java/
    require 'argot/jruby/reader'
else
    require 'argot/mri/reader'
end
require 'argot/pipeline'
require 'argot/flattener'
require 'argot/suffixer'
