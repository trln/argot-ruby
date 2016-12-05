require 'stringio'
require 'set'
require 'jbundler'
require 'java'

# make imports a little easier
def org
    Java::Org
end

java_import org.noggit.JSONParser
java_import org.noggit.ObjectBuilder

##
# A basic reader for Argot JSON.
class Argot::Reader

	#  receiver for error messages, consisting of the invalid deserialized record and the result containing
	#  the error messages
	# @yieldparam rec,Argot::ValidationResult 
	attr_writer :error_receiver

	##
	# The validator used to filter incoming records.
	#  @return Argot::Validator
	attr_reader :validator, :errors

	##
	# Initializes a reader with a set of validators and, if a block is supplied,
	# an error handler.
	# @param validator [Argot::Validator] validator used as a filter for each JSON record read by this reader.
	# @param error_receiver [Proc] (optional) a `#call`-able that takes two arguments, an {+Argot::ValidationResult+}[rdoc-ref:ValidationResult]
	#   and the record that was read.  The default is to output both to the console.
	def initialize(validator=Argot::Validator.from_files, &error_receiver)  
		@validator = validator
		@errors = []
		if error_receiver.nil?
			error_receiver = lambda do |err,record| 
				if err.has_errors? 
					errors << { :record  => record, :error => err }
				end
			end
		end
		@error_receiver = error_receiver
	end

	##
	# Process an IO/File/HTTP stream
	# @param input [IO,String] containing 'streaming' JSON
	# @yield [rec] (hash) a valid Argot record {@see :validator}
	# 
	def process(input, options={})
        encoding = java.nio.charset.Charset.forName(options['encoding'] || 'utf-8')
        if input.java_kind_of?(java.io.Reader) # java reader, nothing to do
            reader = input
        elsif input.java_kind_of?(java.io.InputStream)
            reader = java.io.InputStreamReader.new(input, encoding)
        elsif input.respond_to?(:read) # looks like an IO object
            reader = java.io.InputStreamReader.new(input.to_inputstream, encoding)
        end
        reader = java.io.LineNumberReader.new(reader)
        @parser = JSONParser.new(reader)
        @builder = ObjectBuilder.new(@parser)
        begin
            while rec = @builder.getObject
                if @validator.nil? or record_valid?(rec,reader.lineNumber)
                    yield rec
                end
            end
        rescue JSONParser::ParseException => px
            if @parser.lastEvent != JSONParser::EOF
                raise px
            end
        end
	end

	private

	def record_valid?(rec, line_no)    		
		@validator.is_valid?(rec) { |r| r.location = "line #{line_no}"; @error_receiver.call(r, rec) }
	end

	
end
