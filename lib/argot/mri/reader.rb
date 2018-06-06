# frozen_string_literal: true

require 'yajl'
require 'stringio'
require 'json'
require 'fiber'

module Argot
  # A record-by-record reader for JSON/Argot
  class Reader
    include Enumerable

    attr_accessor :input
    ##
    # Initializes a reader
    # @param input [IO,String] a readable object or a string to read
    # the concatenated JSON from.
    def initialize(input)
      @input = prepare(input)
      @parser = Yajl::Parser.new
    end

    ##
    # Process an IO/File/HTTP stream, or JSON text
    # @param input [IO,String] containing 'streaming' JSON
    # @yield [Hash] an Argot record
    def process
      @parser.on_parse_complete = lambda do |rec|
        yield rec
      end
      @parser.parse(@input)
    end

    # Gets an enumeration of the records found in the input.
    def each
      return enum_for(:each) unless block_given?
      fiber = Fiber.new do |x|
        @input.rewind
        @parser.on_parse_complete = ->(rec) { Fiber.yield rec }
        @parser.parse(@input)
      end
      yield fiber.resume while fiber.alive?
    end

    private

    def prepare(input)
      if input.respond_to?(:read)
        input
      else
        StringIO.new(input)
      end
    end
  end
end
