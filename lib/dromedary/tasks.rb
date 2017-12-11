require 'rake'

module Dromedary
  class Tasks
    include Rake::DSL if defined? Rake::DSL
    def install_tasks
      load 'tasks/dromedary.rake'
    end
  end
end
Dromedary::Tasks.new.install_tasks