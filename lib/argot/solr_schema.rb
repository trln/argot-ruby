# frozen_string_literal: true

require 'nokogiri'
require 'uri'
require 'net/http'

module Argot
  # Represents a Schema in Solr, and provides for some
  # basic checking of input documents against that schema
  class SolrSchema
    EMPTY = {}.freeze

    DEFAULT_SCHEMA = File.join(File.expand_path('../data', __dir__), 'solr_schema.xml').to_s.freeze

    # Create a new validator
    # @param schema [String] the path to an XML document or the contents
    #        of such a document.  If it starts with `https?://`, schema will
    #        be fetched via HTTP; if the value ends with `.xml`,
    #        it will be treated as a local filename.  Otherwise, it will be 
    #        treated as the XML content itself.
    def initialize(schema = DEFAULT_SCHEMA, options = {})
      parsable = schema.respond_to?(:start_with?)
      use_http = parsable && schema.start_with?('http://', 'https://')
      @doc = if use_http
               fetch_http(schema) 
             elsif parsable && schema.end_with?('.xml')
               File.open(schema) do |f|
                 Nokogiri::XML(f)
               end
             else
               Nokogiri::XML(schema)
             end
      compile
      # cache of matchers by field name for a speedup
      @matchers = Hash.new { |h, field| h[field] = find_matcher(field) }
    end

    # only checks to see whether a given document is valid
    # against the schema
    def valid?(rec)
      result = analyze(rec)
      yield result if block_given? && result.empty?
      result.empty?
    end

    def as_block
      lambda do |rec|
        valid?(rec)
      end
    end

    # analyzes an input document against the field definitions in the
    # schema, producing a hash that maps fields to validity issues.
    # if the hash is empty, there are no issues (rec is valid)
    # @param rec [Hash<String, Object>] the deserialized JSON record
    def analyze(rec)
      results = rec.collect do |k, v|
        m = @matchers[k]
        if m.nil?
          [k, 'matches no solr field']
        else
          unless _validate_matcher(m, v)
            [k, m[:msg] % v.length]
          end
        end
      end.reject(&:nil?)
      results.nil? || results.empty? ? EMPTY : Hash[results]
    end

    def _validate_matcher(matcher, value)
      if not value.is_a?(Array)
        true
      else
        value.length == 1 || matcher[:multi]
      end
    end

    private

    def fetch_http(url)
      uri = URI(url)
      Nokogiri::XML(Net::HTTP.get(uri))
    end


    def find_matcher(field_name)
      field_match = @fielddefs.find { |m| m.key?(:name) && m[:name] == field_name }
      if field_match.nil?
        field_match = @fielddefs.find_all do |m|
          m.key?(:regexp) && m[:regexp].match(field_name)
        end
        field_match = field_match.max_by { |m| m[:regexp].source.length }
      end
      return if field_match.nil?
      begin
        field_name = field_match[:name] || field_match[:regexp].source[2..-2]
      rescue StandardError
        puts "#{field_match} is cattywumpus"
      end
      msg = "is multi-valued (%d) but '#{field_name}' is singular"
      { name: field_name, multi: field_match[:multi], msg: msg }
    end

    def compile
      mv_default = Nokogiri::XML::Attr.new(@doc, 'multiValued')
      mv_default.content = 'false'
      @fielddefs = []
      @doc.xpath('//field').each do |f|
        attrs = f.attributes
        @fielddefs << { name: attrs['name'].value, multi: 'true' == attrs.fetch('multiValued',mv_default).value }
      end
      @doc.xpath('//dynamicField').each do |f|
        attrs = f.attributes
        multi = attrs.fetch('multiValued', mv_default).value == 'true' 
        @fielddefs << { regexp: Regexp.new('^.' + attrs['name'].value + '$'),
                        multi:  multi }
      end
      @fielddefs
    end
  end
end
