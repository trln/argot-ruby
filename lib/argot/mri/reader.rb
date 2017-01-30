require 'argot/validator'
require 'yajl'
require 'stringio'
require 'set'

##
# A basic reader for Argot JSON.
#

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
		@parser = Yajl::Parser.new
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
	# @yield [Hash] a valid Argot record 
	def process(input)     		
		if not input.respond_to?(:read)
			input = StringIO.new(input)
		end
		@parser.on_parse_complete = lambda do |rec|
			if @validator.nil? or record_valid?(rec, input.lineno)    					
				yield rec    				
			end
		end
		@parser.parse(input)
	end

	private

	def record_valid?(rec, line_no)    		
		@validator.is_valid?(rec) { |r| r.location = "line #{line_no}"; @error_receiver.call(r, rec) }
	end
end
