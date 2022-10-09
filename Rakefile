# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]

# Adds renaming of Rake tasks, from https://blog.ladslezak.cz/2009/06/03/renaming-rake-task/
module Rake
  class Application
    def rename_task(task, oldname, newname)
      @tasks = {} if @tasks.nil?
      @tasks[newname.to_s] = task

      @tasks.delete(oldname)  if @tasks.has_key?(oldname)
    end
  end
end

# add new rename method to Rake::Task class
# to rename a task
class Rake::Task
  def rename(new_name)
    if !new_name.nil?
      old_name = @name

      return if old_name == new_name

      @name = new_name.to_s
      application.rename_task(self, old_name, new_name)
    end
  end
end

Rake::Task[:release].rename(:"release:gem")

desc "Release to RubyGems, but don't create a version tag (for use in release GitHub Action workflow)"
task :"workflow:release:gem" do
  `gem install gem-release`
  `gem release`
end
