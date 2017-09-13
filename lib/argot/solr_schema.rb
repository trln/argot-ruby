require 'nokogiri'
require 'open-uri'

module Argot
  # Represents a Schema in Solr, and provides for some
  # basic checking of input documents against that schema
  class SolrSchema
    EMPTY = {}.freeze

    DEFAULT_SCHEMA = File.join(File.expand_path('../../data', __FILE__), 'solr_schema.xml').freeze

    # Create a new validator
    # @param schema [String] the path to an XML document or the contents
    #        of such a document.  If it starts with `https?://`, schema will
    #        be fetched via HTTP; if the value ends with `.xml`, 
    #        it will be treated as a local filename.  Otherwise, it will be treated
    #        as the XML content itself.
    def initialize(schema = DEFAULT_SCHEMA, options = {})
      use_http = schema.start_with?("http://") || schema.start_with?('https://')
      if use_http
        open(schema) do |f|
          @doc = Nokogiri::XML(f)
        end
      elsif schema.end_with?('.xml')
        File.open(schema) do |f|
          @doc = Nokogiri::XML(f)
        end
      else
        @doc = Nokogiri::XML(schema)
      end
      compile
      # cache of matchers by field name for a speedup
      @matchers = Hash.new { |h, field| h[field] = find_matcher(field) }
    end

    # only checks to see whether a given document is valid
    # against the schema
    def valid?(rec)
      analyze(rec).empty?
    end

    # analyzes an input document against the field definitions in the
    # schema, producing a hash that maps fields to validity issues.
    # if the hash is empty, there are no issues (rec is valid)
    # @param rec [Hash<String, Object>] the deserialized JSON record
    def analyze(rec)
      results = rec.collect do |k, v|
        m = @matchers[k]
        if m.nil?
          [ k, 'matches no solr field' ]
        else 
          unless _validate_matcher(m,v)
            [k , m[:msg] % v.length ]
          end
        end
      end.reject &:nil?
      ( results.nil? || results.empty? ) ? EMPTY : Hash[results]
    end

    def _validate_matcher(m,v)
      if not v.is_a?(Array)
        true
      else
        v.length == 1 || m[:multi]
      end
    end

    private 

    def find_matcher(field_name)
      field_match = @fielddefs.find { |m| m.key?(:name) && m[:name] == field_name }
      if field_match.nil?
        field_match = @fielddefs.find_all do |m|
            m.key?(:regexp) && m[:regexp].match(field_name)
        end.max_by { |m| m[:regexp].source.length }
      end
      unless field_match.nil? 
        begin
          field_name = field_match[:name] || field_match[:regexp].source[2..-2]
        rescue
          puts "#{field_match} is cattywumpus"
        end
        msg = "is multi-valued (%d) but '#{field_name}' is singular"
        { name: field_name, multi: field_match[:multi], msg: msg }
      end
    end

    def compile
      mv_default = Nokogiri::XML::Attr.new(@doc, 'multiValued')
      mv_default.content = 'false'
      @fielddefs = []
      @doc.xpath("//field").each do |f|
        attrs = f.attributes
        @fielddefs << { name: attrs['name'].value, multi: 'true' == attrs.fetch('multiValued',mv_default).value }
      end
      @doc.xpath("//dynamicField").each do |f|
        attrs = f.attributes
        @fielddefs << { regexp: Regexp.new('^.' + attrs['name'].value + '$'),
                       multi: 'true' == attrs.fetch('multiValued', mv_default).value }
      end
      @fielddefs
    end
  end
end
