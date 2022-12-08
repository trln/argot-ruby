# frozen_string_literal: true

require 'set'
require 'uri'
require 'net/http'
require 'ostruct'

module Argot
  # utility method that converts wildcard fields
  # we find in our schema to Regexp objects
  def self.regexify(solr_dyn_field)
    Regexp.new("^.#{solr_dyn_field}$")
  end

  # encapsulates info about a `copyField` element
  # in the schema.
  CopyField = Struct.new(:source, :dest, :regex) do
    def initialize(source, dest, regex = nil)
      self.source = source
      self.dest = dest
      self.regex = regex || Argot.regexify(source)
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

    DF_VALIDATE_REGEX = /\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.freeze

    TYPE_FORMAT_VALIDATORS = {
      date: ->(v) { v.match?(DF_VALIDATE_REGEX) },
      int: ->(v) { v.to_i rescue false }
    }.freeze

    DEFAULT_SCHEMA = File.join(File.expand_path('../data', __dir__), 'solr_schema.json').to_s.freeze

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
             elsif parsable && schema.end_with?('.json')
               File.open(schema) { |f| JSON.parse(f.read) }
             else
               JSON.parse(schema)
             end
      @required = Set.new
      compile
      # cache of matchers by field name for a speedup
      @matchers = Hash.new { |h, field| h[field] = find_matcher(field) }
    end

    # only checks to see whether a given document is valid
    # against the schema
    def valid?(rec)
      result = analyze(rec)
      yield result if block_given? && !result.empty?
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
          errs << m[:msg] % v.length unless validate_arity(m, v)
          unless check_values(m[:field_type], v)
            errs << "one or more of #{v} does not match pattern for field type #{m[:field_type]}"
          end
          errs.empty? ? nil : [k, errs]
        end
      end.compact
      unless (missing = (@required - rec.keys)).empty?
        results += missing.collect { |f| [f, "missing required field"] }
      end

      results.nil? || results.empty? ? EMPTY : Hash[results]
    end

    def check_values(field_type, value)
      return true unless field_type && (validator = TYPE_FORMAT_VALIDATORS[field_type.to_sym])

      value = [value] unless value.respond_to?(:each)
      value.all? { |v| validator.call(v) }
    end

    private

    # solr is very forgiving; multiValued fields submitted as scalars
    # are OK (converted to 1-ary array in index)
    # and single-valued fields submitted as 1-ary arrays are also
    # OK
    def validate_arity(matcher, value)
      return true unless value.respond_to?(:each)
      return true if value.is_a?(String)
      matcher[:multi] || value.length == 1
    end

    def fetch_http(url)
      uri = URI(url)
      Net::HTTP.get(uri)
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
      msg = if field_match[:multi]
              "is multi-valued (%d) but '#{field_name}' is singular"
            else
              "is singular but '#{field_name}' contains %d values"
            end
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
      @fielddefs = []
      schema = OpenStruct.new(@doc['schema'])

      @copy_fields = schema.copyFields.map do |f|
        CopyField.new(f['source'], f['dest'])
      end

      @static_fields = schema.fields.each_with_object({}) do |f, h|
        h[f['name']] = f
        @required << f['name'] if f['required']
      end

      @dynamic_fields = schema.dynamicFields.each_with_object({}) do |f, h|
        h[f['name']] = f
      end

      @static_fields.each do |name, attrs|
        field = { name: name, multi: attrs.fetch('multiValued', false), type: attrs['type'] }
        @fielddefs << field
      end
      merge_copy_fields

      @static_fields.each do |name, attrs|
        field = { name: name, multi: attrs.fetch('multiValued', false), type: 'type' }
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
        multi = attrs.fetch('multiValued', false)
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
