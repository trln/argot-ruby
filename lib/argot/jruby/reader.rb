require 'stringio'
require 'set'
require 'java'

# make imports a little easier
def org
  Java::Org
end

begin
  require 'argot_jars'
rescue
  $stderr.write 'argot_jars not found'
end

begin
  java_import java.nio.charset.Charset
  java_import org.noggit.JSONParser
  java_import org.noggit.ObjectBuilder
rescue
  $stderr.write 'noggit classes not found.'
  $stderr.write ' This is not a problem during installation\n'
end

module Argot
  ##
  # A basic reader for Argot JSON.
  class Reader
    # Process an IO/File/HTTP stream
    # @param input [IO,String] containing 'streaming' JSON
    # @yield [Hash] an Argot record
    def process(input, options = {})
      options[:encoding] ||= 'utf-8'
      reader = _get_reader(input, options)
      _init(reader)
      begin
        # rubocop:disable Lint/AssignmentInCondition
        while rec = @builder.getObject
          yield rec
        end
      rescue JSONParser::ParseException => px
        raise px unless @parser.lastEvent == JSONParser::EOF
      end
    end

    private

    def _init(reader)
      @parser = JSONParser.new(reader)
      @builder = ObjectBuilder.new(@parser)
    end

    def _get_reader(input, options)
      encoding = Charset.forName(options[:encoding]
      $stderr.write input.java_class
      if input.java.is_a?(java.io.Reader)
        reader = input
      elsif input.java.kind_of?(java.io.InputStream)
        reader = java.io.InputStreamReader.new(input, encoding)
      elsif input.respond_to?(:to_inputstream) 
        reader =  java.io.InputStreamReader.new(input.to_inputstream, encoding)
      else
        reader = java.io.StringReader.new(input)
      end
      java.io.LineNumberReader.new(reader)
    end
  end # class
end
