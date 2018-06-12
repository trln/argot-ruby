require 'stringio'
require 'set'
require 'java'

# make imports a little easier
def org
  Java::Org
end

begin
  require 'argot_jars'
rescue LoadError
  warn 'argot_jars not found'
end

begin
  java_import java.nio.charset.Charset
  java_import org.noggit.JSONParser
  java_import org.noggit.ObjectBuilder
rescue NameError
  warn 'noggit classes not found.'
  warn ' This is not a problem during installation\n'
end

module Argot
  ##
  # A basic reader for Argot JSON.
  class Reader
    include Enumerable

    attr_reader :count

    def initialize(input, options = {})
      options[:encoding] ||= 'utf-8'
      reader = _get_reader(input, options)
      _init(reader)
    end

    def each
      return enum_for(:each) unless block_given?
      begin
        @count = 0
        while (rec = @builder.getObject)
          @count += 1
          yield rec
        end
      rescue JSONParser::ParseException => px
        raise px unless @parser.lastEvent == JSONParser::EOF
      end
    end

    alias process each

    private

    def _setup(input, options = {})
      options[:encoding] ||= 'utf-8'
      reader = _get_reader(input, options)
      _init(reader)
    end

    def _init(reader)
      @parser = JSONParser.new(reader)
      @builder = ObjectBuilder.new(@parser)
    end

    def _get_reader(input, options)
      encoding = Charset.forName(options[:encoding])
      reader = if input.java.is_a?(java.io.Reader)
                 input
               elsif input.java.is_a?(java.io.InputStream)
                 java.io.InputStreamReader.new(input, encoding)
               elsif input.respond_to?(:to_inputstream)
                 java.io.InputStreamReader.new(input.to_inputstream, encoding)
               else
                 java.io.StringReader.new(input)
               end
      java.io.LineNumberReader.new(reader)
    end
  end
end
