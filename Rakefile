require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rspec/core/rake_task'

begin
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  warn "rspec not available.  this is bad."
end


if RUBY_PLATFORM =~ /java/
    require 'jars/installer'
end

desc "Run tests"
task :default => :spec
