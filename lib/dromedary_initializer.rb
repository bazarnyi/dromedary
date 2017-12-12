module DromedaryInitializer
  def self.run
    if cucumber_not_initialized?
      report_no_cucumber_found
    elsif already_initialized?
      report_already_initialized
    else
      create_file 'config/dromedary.yml'
      create_file 'features/support/dromedary_hooks.rb'
      create_file 'config/cucumber.yml'
      create_file 'Rakefile'

      update_file 'config/dromedary.yml', dromedary_config_content
      update_file 'features/support/dromedary_hooks.rb', dromedary_hooks_content

      update_file 'config/cucumber.yml', cucumber_config_content
      update_file '.gitignore', gitignore_content
      update_file 'Rakefile', rakefile_content
      update_file 'Gemfile', gemfile_content
    end
  end

  def self.create_directory(dir_name)
    create_directory_or_file dir_name, true
  end

  def self.create_file(file_name)
    create_directory_or_file file_name, false
  end

  def self.create_directory_or_file(file_name, directory)
    file_type = if directory
                  :mkdir_p
                else
                  :touch
                end

    report_exists(file_name) || return if File.exist?(file_name)

    report_creating(file_name)
    FileUtils.send file_type, file_name
  end

  def self.update_file(file_name, content)
    open(file_name, 'a') do |file|
      content.flatten!.each do |line|
        file.puts line
      end
    end

    report_updating(file_name)
  end

  def self.cucumber_not_initialized?
    !File.exist?('features/support/env.rb')
  end

  def self.already_initialized?
    File.exist?('config/dromedary.yml') || File.exist?('features/support/dromedary_hooks.rb')
  end

  def self.report_exists(file)
    puts "     exist   #{file}"
  end

  def self.report_creating(file)
    puts "  creating   #{file}"
  end

  def self.report_updating(file)
    puts "  updating   #{file}"
  end

  def self.report_no_cucumber_found
    puts "  Dromedary had searched all Sahara desert for Cucumber, but didn't found it"
    puts '  Are you sure that you had initialized Cucumber project?'
    puts "  If not, try to run 'cucumber --init' first"
  end

  def self.report_already_initialized
    puts '  Our suspicious Dromedary says that you have already initialized it'
    puts "  There is no need to run 'dromedary -- init' command more than once"
  end

  def self.dromedary_config_content
    ['# This file was generated by Dromedary gem',
     '# It contains required settings to support TestRail integration',
     '# Fill in each line with credentials of your TestRail account',
     '',
     dromedary_config_structure,
     ' # By default Dromedary creates Test Runs on TestRail this way:',
     ' # test_run_default_name + Suite Type + on Environment',
     ' # So at the end you will get something like this:',
     ' # "My_project Regression on Staging"']
  end

  def self.dromedary_config_structure
    ['testrail:',
     ' url:',
     ' user:',
     ' password:',
     ' project_id:',
     ' suite_id:',
     ' test_run_default_name:']
  end

  def self.dromedary_hooks_content
    ['# This file was generated by Dromedary gem',
     '# It contains required Cucumber hooks to ensure that all reporting works',
     '# Do not edit this file',
     '',
     dromedary_hooks_structure]
  end

  def self.dromedary_hooks_structure
    [dromedary_before_hooks,
     '',
     dromedary_afterstep_hooks,
     '',
     dromedary_after_hooks]
  end

  def self.dromedary_before_hooks
    ['Before do',
     "  # setting environment to 'local' in order not to generate reporting",
     "  # if you need individual reports, just put this variable to 'false'",
     "  ENV['local'] ||= 'true'",
     "  @local = ENV['local']",
     '',
     '  # creating results hash for TestRail',
     '  @results = {}',
     '  # and resetting passed steps count',
     '  @passed_steps_count = 0',
     'end']
  end

  def self.dromedary_afterstep_hooks
    ['AfterStep do |step|',
     '  @passed_steps_count += 1 if step.passed?',
     'end']
  end

  def self.dromedary_after_hooks
    ['After do |scenario|',
     '  # updating results hash for TestRail after each scenario',
     '  feature_name = scenario.feature.name',
     '  scenario_name = scenario.name',
     '',
     '  scenario.test_steps.each do |step|',
     "    if step.text != 'Before hook' && step.text != 'AfterStep hook'",
     "      step_name = File.open(step.location.file).readlines[step.location.line-1].lstrip",
     "      full_description = (feature_name + ' ' + scenario_name + ' ' + step_name).rstrip",
     '      status_id = []',
     '      status_id =  @passed_steps_count > 0 ? (status_id.push 1) : (status_id.push 5)',
     '      if @results[ full_description ]',
     '        @results[ full_description ].push(status_id).flatten!',
     '      else',
     '        @results[ full_description ] = status_id',
     '      end',
     '      @passed_steps_count -= 1',
     '    end',
     '  end',
     '',
     '  # setting TestRail to generate reports at specific folder',
     "  unless @local == 'true'",
     '    File.open("artifacts/testrail_reports/file_#{Time.now.to_i}.json}.json", "w") do |file|',
     '      file.puts @results.to_json',
     '    end',
     '  end',
     'end']
  end

  def self.cucumber_config_content
    ['',
     '# Following lines were generated by Dromedary gem',
     '# It contains required Cucumber profiles to ensure that all reporting works',
     '',
     cucumber_config_structure]
  end

  def self.cucumber_config_structure
    ['junit_report: --format pretty --format junit --out artifacts/junit_xml_reports',
     'run_json_report: --format json --out artifacts/cucumber_json_reports/run.json',
     'rerun_json_report: --format json --out artifacts/cucumber_json_reports/rerun.json',
     'rerun_formatter: --format rerun --out artifacts/final_test_reports/fails.log']
  end

  def self.gitignore_content
    ['',
     gitignore_structure]
  end

  def self.gitignore_structure
    ['artifacts/']
  end

  def self.rakefile_content
    ['',
     '',
     '# require Dromedary gem dependencies',
     rakefile_structure]
  end

  def self.rakefile_structure
    ["require 'dromedary/tasks'",
     '',
     '# describing Dromedary rake tasks',
     "desc 'Rake task to run all the Dromedary sequence'",
     'task :run_dromedary, :run_on do |task, args|',
     '  ENV["RUN_ON"] = "#{args[:run_on]}"',
     '  %W[prepare_for_a_ride store_cases_titles run_cucumber merge_junit_reports get_case_ids[run] rerun_if_needed generate_cucumber_json_reports create_run[smoke,#{args[:run_on]}] close_run[#{args[:run_on]}] final_clean_ups].each do |task_name|',
     '    sh "rake #{task_name}" do',
     '      #ignore errors',
     '    end',
     '  end',
     'end']
  end

  def self.gemfile_content
    ['',
     gemfile_structure]
  end

  def self.gemfile_structure
    ["gem 'junit_merge'"]
  end
end