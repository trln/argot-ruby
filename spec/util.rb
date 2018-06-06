require 'yaml'

module Util
  TEST_FILES = File.expand_path('../data', __FILE__)

  # finds a test data file's full name
  def find_file(name)
    path = File.join(TEST_FILES, name)
    raise "Can't find #{name}" unless File.exist?(path)
    yield path if block_given?
    path
  end

  # opens a test data file for reading.
  # if a block is given, returns the result
  # of evaluating the block
  def open_file(name)
    file = File.open(find_file(name), 'r')
    if block_given?
      begin
        return yield file
      ensure
        file.close
      end
    end
    file
  end

  # reads a JSON file containing a single object into
  # a Ruby object  
  def get_json(name)
    r = {}
    open_file(name) do |f|
      r = JSON.parse(f.read)
      yield r if block_given?
    end
    r
  end

  def yaml_fixture(name)
    open_file(name + '.yml') do |f|
      YAML.load_file(f)
    end
  end

  # Flattens data found in a JSON file to a single
  # test record.
  def flatten_test_record(argot_filename, config = {})
    instance = Argot::Flattener.new
    instance.config.merge(config)
    doc = open_file(argot_filename) do |f|
      JSON.parse(f.read)
    end
    instance.call(doc)
  end

  def fixture_expectations(exp_file, record)
    expectations = yaml_fixture(exp_file)
    return expectations.map do |field, ev|
      if ev.respond_to?(:has_key?) && ev.has_key?('json')
        ev = ev['json']
        record[field] = record[field].collect{ |e| JSON.parse(e) }
      end
      [ record, field, ev ]
    end
  end

  # Utility sub-module containing methods for use outside specific
  # examples (e.g. in the context of a 'describe' or 'context' but not
  # within an 'it')
  module Extend
    include Util
    # Generate a list of expectations from a YAML file.
    # the YAML file defines a hash, each key of which is expected
    # to be a record in the output of a flattener, and the values
    # of which are the values of the field.
    # Wrinkle for output where the field is serialized JSON,
    # if the value in the YAML is a hash with the key 'json',
    # then the 
    # e.g.
    # 
    # foo_field:
    #   - value 1
    #   - value 2
    #   
    # foo_json_field:
    #   json:
    #     - "{ \"
    def load_expectations(exp_file, record)
      yaml_fixture(exp_file).map do |field, ev|
        if ev.respond_to?(:has_key?) && ev.has_key?('json')
          ev = ev['json']
          record[field] = record[field].collect{ |e| JSON.parse(e) }
        end
        [ record, field, ev ]
      end
    end
  end


end
