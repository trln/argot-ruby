require 'argot'

require 'yajl'
require 'stringio'
require 'set'

##
# A basic reader for Argot JSON.
class Argot::Reader

	##
	# Initializes a reader with a set of validators and, if a block is supplied,
	# an error handler.
	# * +validator+ an {+Argot::Validator+}[rdoc-ref:Argot::Validator] that will be used to check each record read by this reader.
	# * +error_receiver+ (optional) a +#call+-able that takes two arguments, an {+Argot::ValidationResult+}[rdoc-ref:ValidationResult]
	#   and the record that was read.  The default is to output both to the console.
	def initialize(validator=Argot::Validator.from_files, &error_receiver)  
		@validator = validator
		@parser = Yajl::Parser.new
		if error_receiver.nil?
			error_receiver = lambda do |err,record| 
				if err.has_errors? 
					puts record
					puts err 
				end
			end
		end
		@error_receiver = error_receiver
	end


	##
	# Process an IO/File/HTTP stream
	# * +input+ : an IO object or String containing 'streaming' JSON
	# 
	def process(input)     		
		if not input.respond_to?(:read)
			input = StringIO.new(input)
		end
		@parser.on_parse_complete = lambda do |rec|
			if @validator.nil? or record_valid?(rec)    					
				yield rec    				
			end
		end
		@parser.parse(input)
	end

	private

	def record_valid?(rec)    		
		@validator.is_valid?(rec) { |r| @error_receiver.call(r, rec) }
	end

	
end
