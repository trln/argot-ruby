module Util
    TEST_FILES = File.expand_path("../data", __FILE__)

    def self.get_file(name)
        f = File.new(File.join(Util::TEST_FILES, name))
        if not File.exist?(f)
            raise "Unable to find required test file #{name}"
        end
        f
    end
end

