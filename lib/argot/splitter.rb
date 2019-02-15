# frozen_string_literal: true

require 'fileutils' 

module Argot
  # methods to split an input file into multiple output files
  class Splitter
    DEFAULT_CHUNK_SIZE = 20_000
    DEFAULT_PATTERN = 'add-argot-%d.json'

    attr_accessor :chunk_size, :pattern
    attr_reader :dir, :path, :current_file, :record_count, :file_count

    def initialize(dir,
                   chunk_size: DEFAULT_CHUNK_SIZE,
                   pattern: DEFAULT_PATTERN)
      @dir = dir
      @record_count = @file_count = 0
      @pattern = pattern
      @chunk_size = chunk_size
      return unless block_given?

      begin
        yield self
      ensure
        close
      end
    end

    def write(rec)
      next_file unless current_file

      current_file.write(rec.is_a?(String) ? rec : rec.to_json)
      @record_count += 1
      return unless (record_count % chunk_size).zero?

      close
      @current_file = nil
    end

    def next_file
      @file_count += 1
      close
      @current_file = open_next_file
    end

    def close
      !current_file&.closed? && current_file&.fsync && current_file&.close
    end

    private

    def open_next_file
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      @path = File.join(dir, format(pattern, file_count))
      File.open(path, 'w')
    end
  end
end
