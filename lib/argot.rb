##
# Argot -- tools for working with TRLN shared record format.
# +require+-ing this module also imports the +Argot::Validator+ and +Argot::Reader+ classes.
# 
# Other tools and utilities that are available
# {+Argot::TrajectJSONWriter+}[rdoc-ref:Argot::TrajectJSONWriter] (+require 'argot/traject_writer'+) - a Traject Writer implementation that converts the usual Traject output format more friendly 
# {+Argot::XML::EventHandler+}[rdoc-ref:Argot::XML::EventHandler] (+require 'argot/xml.rb'+) - a wrapper around Nokogiri XML parser that allows processing large XML files as each element is built.
module Argot
	VERSION = '0.0.4'
end

require 'argot/validator'

if RUBY_PLATFORM =~ /java/
    require 'argot/jruby/reader'
else
    require 'argot/mri/reader'
end
require 'argot/pipeline'
