require 'argot/validator'
require 'yajl'
require 'stringio'
require 'set'

##
# A basic reader for Argot JSON.
#
class Argot::Reader

    ##
    # Initializes a reader with a set of validators and, if a block is supplied,
    # an error handler.
    # @param validator [Argot::Validator] validator used as a filter for each JSON record read by this reader.
    # @param error_receiver [Proc] (optional) a `#call`-able that takes two arguments, an {+Argot::ValidationResult+}[rdoc-ref:ValidationResult]
    #   and the record that was read.  The default is to output both to the console.
    def initialize()  
        @parser = Yajl::Parser.new
    end

    ##
    # Process an IO/File/HTTP stream, or JSON text
    # @param input [IO,String] containing 'streaming' JSON
    # @yield [Hash] an Argot record 
    def process(input)
        if not input.respond_to?(:read)
            input = StringIO.new(input)
        end
        @parser.on_parse_complete = lambda do |rec|
            yield rec 
        end
        @parser.parse(input)
    end
end
