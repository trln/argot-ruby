require 'yaml' 
require 'ostruct'

module Argot

    ##
    # Struct representing the result of invoking a rule on a record.
    # * +name+ : the name (short description) of the rule
    # * +errors+ : an array of strings indicating errors with the record
    # * +warnings+ : an array of strings indicating problems with the record
    #   that will not result in its being rejected.
    RuleResult = Struct.new('RuleResult',:name,:errors,:warnings) do
        ##
        # creates a new empty instance 
        def self.empty(name) 
            RuleResult.new(name,[].freeze, [].freeze).freeze
        end
    end

    ##
    # Struct representing the result of invoking all of a Validator's rules
    # on a record.
    # * +location+ : the location of the error in the source.
    #   it is up to the caller to provide this and the consumer to
    #   interpret.
    # @param [Array<Hash>] :errors  :rule => rule.name, :errors => rule errors }+
    # * +warnings+ : an array of +{ :rule => rule.name, :warnings => rule.warnings }+
    ValidationResult = Struct.new(:location, :errors, :warnings) do
      def self.create(location = 0)
        ValidationResult.new(location, [], [])
      end

      ##
      # Checks whether any of the rules contained in this result reported
      # an error
      def errors?
        !errors.empty?
      end


      def first_error
        if errors.nil? || errors.empty?
          nil
        else
          errors.first.fetch(:errors, []).first
        end
      end

      ##
      # Adds the result of an individual rule to this result.
      # * +result+ a :rdoc-ref RuleResult instance
      def <<(result)
        unless result.errors.empty?
          errors << { rule: result.name, errors: result.errors }
        end
        unless result.warnings.empty?
          warnings << { rule: result.name, warnings: result.warnings }
        end
        self
      end
    end

    ##
    # Basic implementation of a validator for JSON files in the 'argot'
    # format.  Allows loading of rules from YAML files in a default location
    # and adding rules generated programmatically.
    class Validator

      DEFAULT_PATH = File.expand_path('../data', __dir__)

      attr_accessor :rules

      attr_reader :rules_files

      def self.load_files(files=[])
        files = default_files if files.empty?
        files
      end

      ##
      # Creates a new instance from YAML files specified as arguments.
      # * +rules_files+ - an array of filenames to load rules from
      #   If no files are specified, loads rules from files named +rule\*.yml+
      #   this gem's data directory (+../../data+ relative to this file)
      # see BasicRule for examples.
      def self.from_files(rules_files = [])
        rules_files = load_files(rules_files)
        Validator.new(compile(rules_files))
      end


      def self.default_files
        Dir.glob(DEFAULT_PATH + '/rule*.yml').collect
      end

      ##
      # Compiles an array of YAML rules files into executable rules
      # * +files+ : an array of File objects from which to load rules.
      #
      # return value is a list of executable rules.
      #
      # see BasicRule for documentation format
      def self.compile(files)
        rules = []
        files.select { |f| f && File.exist?(f) }.collect do |name|
          ruledefs = File.open(name) { |f| YAML.safe_load(f) }
          ruledefs.each do |rd|
            rules << BasicRule.new(rd)
          end
        end
        rules.flatten
      end

      ##
      # Creates a new validator with a supplied set of rules.
      # @param [Array<BasicRule>] rules the rules to be used to check 
      # records.  If empty, will load rules from a default set of YAML
      # files (`../data/rule*.yml`)
      def initialize(rules = [])
        if rules.empty?
          rules = self.class.compile(self.class.default_files)
        end
        @rules = rules
      end

      ##
      # Adds a new rule on to the end of existing rules
      # Rule must be in the form of a 'callable' that returns
      # an object corresponding to the basic structure of
      # the RuleResult struct.
      def <<(rule)
        unless rule.respond_to?(:call)
          raise 'Rules added with << must respond to #call'
        end
        @rules << rule
      end

      def call(rec, location = 0)
        results = ValidationResult.create(location)
        @rules.each do |r|
          begin
            result = r.call(rec)
          rescue StandardError => e
            result = RuleResult.new(r.data.name, [e.message], [e.backtrace.inspect])
          end
          results << result
        end
        yield results if block_given?
        results
      end

      ##
      # Tests the record for validity.
      # if a block is supplied,  it will be called with the input record and
      # the validation result object that indicates errors
      # @param [Hash<String, Object>] rec the Argot record to be validated.
      # @param [Fixnum] location the location in a source file currently being
      # processed.
      # @return [Bool] true if the record is valid, false if not
      # @yield [rec, result] an handler to be invoked if the record is not valid
      # @yieldparam [Hash] rec the input record
      # @yieldparam [ValidationResult] result the validation result, which
      #  includes error messages
      def valid?(rec, location = 0, &block)
        results = call(rec, location)
        valid = results.errors.empty?
        yield(rec, results) if block_given? && !valid
        valid
      end

      ##
      # yields a block=version of this validator, which calls #valid?
      # This is not a wrapper around #call because the common usage of this
      # validator is to serve as a filter.  Filtered results can be logged
      def as_block
        lambda do |rec|
          valid?(rec)
        end
      end
    end

    # Tests for types when running under JRuby; in order to
    # avoid problem of Java` namespace not being defined under
    # MRI, put these checks behind a platform test.
    module JRubyTests

      def jruby?
        @jruby ||= ( RUBY_PLATFORM =~/java/ )
      end

      def java_list?(obj)
        jruby? && obj.is_a?(Java::JavaUtil::List) 
      end

      def java_string?(obj)
        jruby? && obj.is_a?(Java::JavaLang::String)
      end

      def java_integer?(obj)
        jruby? && obj.is_a?(Java::JavaLang::Integer)
      end
    end

    ##
    # Implementation of a rule that can be loaded from a data file.  Supported attributes:

    # * +name+ : (required) the name and short description of a rule.
    # * +path+ : (required) the path within an argot document to the field this rule handles
    #   e.g. +title.main+ refers to the +main+ attribute of the top-level +title+ attribute.
    # * +required+ : (optional, defaults to +false+) whether the field must be present in the document.
    # * +type+ : (optional) - the expected Ruby type of object at +path+, e.g. +String+, `Array` or +Integer+.
    # * +single+ : (optional, defaults to +false+) - there should only be 1 value
    #   this attribute is only used to check validity if the field is present.  If left
    #   unspecfied, no type checking will be done.
    #
    # === YAML
    # rules can be specified in a YAML file using the syntax:
    #  - name : 'Title' attribute must be present
    #    path : title
    #    required : true
    #  - name : 'local_id' attribute is required
    #    path : local_id
    #    required: true
    #    type : String
    # The above defines two rules, one of which checks for the existence of a 'title' attribute that
    # can have any value, and the other which verfies the presence of a +local_id+ attribute that is a 
    # ruby String (i.e. if local_id is itself an object, this rule would be violated)
    class BasicRule
      include JRubyTests
      attr_reader :data

      ##
      # Creates a rule from a data structure.
      # * +rule_obj: a data structure that contains at least a
      # +name+ and +path+ attribute, as detailed above.
      def initialize(rule_obj)
        @data = OpenStruct.new(rule_obj)
        compile
      end

      ## 
      # Checks whether a given value looks like an array
      # (use this for cross-platform compatibility; JRuby
      # `Array`s are ofen `java.util.List`s
      def arrayish?(obj)
        obj.is_a?(Array) || java_list?(obj)
      end

      def stringish?(obj)
        obj.is_a?(String) || java_string?(obj)
      end

      def integerish?(ob)
        obj.is_a?(Integer) || java_integer?(obj)
      end

      ##
      # invokes the rule against the supplied record
      # * +rec+ : the Argot record to be validated
      # :returns: a RuleResult (or equivalent)
      # rubocop:disable MethodLength, LineLength
      def call(rec)
        result = RuleResult.new(@data.name, [], [])
        value = @expr.call(rec)
        result.errors << "#{@data.path} not found" if value.nil? && @data.required
        unless @data.type.nil?
          typestr = @data.type.to_s
          type_check = case typestr
                       when 'Array'
                         arrayish?(value)
                       when 'String'
                        stringish?(value)
                       when 'Integer'
                        integerish?(value)
                       else
                         typestr == value.class.to_s
                       end
          result.errors << "#{@data.path} should be type #{@data.type} (found: #{value.class})" unless type_check
        end
        if arrayish?(value) && @data.single
          unless value[1].nil?
            result.errors << "#{@data.path} should only have a single value, multiple values found"
          end
        end
        result
      end

      private

      def empty_result
        RuleResult.new(data.name, [].freeze, [].freeze)
      end

      def compile
        keys = data.path.split('.')
        @expr = lambda do |hash|
          keys.inject(hash) do |obj, key|
            begin
              result = obj[key]
            rescue
              nil
            end
            result
          end
        end
      end
    end
end
