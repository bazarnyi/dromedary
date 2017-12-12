Gem::Specification.new do |s|
  s.name        = 'dromedary'
  s.version     = '0.2.28'
  s.executables << 'dromedary'
  s.date        = '2017-12-07'
  s.summary     = 'Test reporting helper gem'
  s.description = 'Dromedary is a helper gem which will unify and simplyfy test reporting approaches for different Ruby Based Test Automation Solutions'
  s.authors     = ['Denys Bazarnyi']
  s.email       = 'denys.bazarnyi@storecast.de'
  s.files       = ['lib/dromedary.rb', 'lib/dromedary_initializer.rb', 'lib/dromedary/tasks.rb', 'lib/tasks/dromedary.rake', 'lib/testrail.rb']
  s.homepage    =
      'http://rubygems.org/gems/dromedary'
  s.license     = 'MIT'
end