# frozen_string_literal: true

module Argot
  def self.version
    unless Argot.const_defined? :VERSION
      @version ||= File.read(File.join(__dir__, '..', '..', 'VERSION')).chomp
    end
  end

  VERSION = version.freeze
end
