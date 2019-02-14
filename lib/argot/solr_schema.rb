# frozen_string_literal: true

require 'nokogiri'
require 'uri'
require 'net/http'

module Argot
  # utility method that converts wildcard fields
  # we find in our schema to Regexp objects
  def self.regexify(solr_dyn_field)
    Regexp.new('^.' + solr_dyn_field + '$')
  end

  # encapsulates info about a `copyField` element
  # in the schema.
  CopyField = Struct.new(:source, :dest, :regex) do
    def initialize(source, dest, regex = nil)
      self.source = source
      self.dest = dest
      self.regex = regex ? regex : Argot.regexify(source)
    end

    def match?(field_name)
      field_name.match?(regex)
    end
  end

  # Representation of a Solr Schema of the sort used in
  # TRLN Discovery
  class SolrSchema
    attr_reader :fielddefs
    EMPTY = {}.freeze

    DF_VALIDATE_REGEX = /\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/

    TYPE_FORMAT_VALIDATORS = {
      date: ->(v) { v.match?(DF_VALIDATE_REGEX) },
      int: ->(v) { v.to_i rescue false }
    }.freeze

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
          errs = []
          errs << m[:msg] % v.length unless _validate_matcher(m, v)
          unless check_values(m[:field_type], v)
            errs << "one or more of #{v} does not match pattern for field type #{m[:field_type]}"
          end
          errs.empty? ? nil : [k, errs]
        end
      end.reject(&:nil?)
      results.nil? || results.empty? ? EMPTY : Hash[results]
    end

    def check_values(field_type, value)
      return true unless field_type && (validator = TYPE_FORMAT_VALIDATORS[field_type.to_sym])

      value = [value] unless value.is_a?(Array)
      value.all? { |v| validator.call(v) }
    end

    def _validate_matcher(matcher, value)
      return true unless value.is_a?(Array)

      value.length == 1 || matcher[:multi]
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
      { name: field_name, multi: field_match[:multi], msg: msg, field_type: field_match[:type] }
    end

    # makes sure every copy field definition 
    # maps the destination field and its type.
    def merge_copy_fields
      @copy_fields.each do |c|
        if (dynamic = @dynamic_fields[c.dest])
          c.dest = dynamic
        elsif (static = @static_fields[c.dest])
          c.dest = static
        end
      end
    end

    def field_to_hash(field)
      hash = Hash[field.attributes.map do |name, att| 
        [name, att.value]
      end]
      [hash['name'], hash.tap { |h| h.delete('name') }]
    end

    def compile
      mv_default = Nokogiri::XML::Attr.new(@doc, 'multiValued')
      mv_default.content = 'false'
      @fielddefs = []

      @copy_fields = @doc.xpath('//copyField').map do |f|
        CopyField.new(f.attributes['source'].value, f.attributes['dest'].value)
      end

      @static_fields = Hash[@doc.xpath('//field').map { |f| field_to_hash(f) }]
      @dynamic_fields = Hash[@doc.xpath('//dynamicField').map do |f|
        field_to_hash(f)
      end]

      @static_fields.each do |name, attrs|
        field = { name: name, multi: 'true' == attrs['multiValued'], type: 'type' }
        @fielddefs << field
      end
      merge_copy_fields

      @static_fields.each do |name, attrs|
        field = { name: name, multi: attrs['multiValued']== 'true', type: 'type' }
        copy = @copy_fields.find { |c| c.match?(name) }
        field[:type] = copy.dest['type'] if copy
        @fielddefs << field
      end

      # now all the copyField directives should have a 'dest'
      # that maps to the dynamicField matching the dest pattern
      # e.g.
      # 1. dynamicField *_dt => type date
      # 2. dynamicFIeld *_dt_single_stored => type ignored
      # 3. copyField source *_dt_single_stored dest: *_dt
      # any field matching 2 is going to be (3) copied to *_dt and so must
      # match the type in (1).
      @dynamic_fields.each do |name, attrs|
        multi = attrs.fetch('multiValued', 'false') == 'true'
        field = { regexp: Argot.regexify(name),
                  type: attrs['type'],
                  multi:  multi }
        copy = @copy_fields.find { |c| c.match?(name) }
        field[:type] = copy.dest['type'] if copy
        @fielddefs << field
      end
      @fielddefs
    end
  end
end
