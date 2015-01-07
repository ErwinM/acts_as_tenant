require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec

desc 'Run the test suite for all supported ORMs.'
namespace :spec do
  task :all do
    %w[active_record mongoid].each do |orm|
      ENV["ORM"] = orm
      Rake::Task["spec"].reenable
      Rake::Task["spec"].invoke
    end
  end
end
