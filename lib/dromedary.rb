require 'rake'
require_relative 'dromedary_initializer'

class Dromedary
  include DromedaryInitializer

  def self.init(options)
    case options
    when '--init'
      show_init_msg
      initialize_project
    else
      welcome
    end
  end

  def self.welcome
    puts 'Hello world! I am a wild Dromedary!'
    puts 'If you like to take a ride, you will need to run "dromedary --init" first'
  end

  def self.initialize_project
    DromedaryInitializer.run
  end

  def self.show_init_msg
    puts 'Initializes folder structure and generates files for Dromedary reporting'
  end
end