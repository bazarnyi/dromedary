require 'nokogiri'
require 'yaml'
require_relative '../testrail'

DROMEDARY = YAML.load_file("#{Dir.pwd}/config/dromedary.yml")

# TASKS

# Preparation tasks

desc 'This task creates required folders and files'
task :prepare_for_a_ride do
  %W[create_folders create_files].each do |task_name|
    sh "rake #{task_name}" do
      #ignore errors
    end
  end
end

desc 'This task creates required folder tree for reporting'
task :create_folders do
  %W[artifacts artifacts/cucumber_json_reports artifacts/junit_xml_reports artifacts/testrail_reports artifacts/final_test_reports].each do |dir_name|
    Dir.mkdir "#{dir_name}"
  end
end

desc 'This task creates and updates required files for reporting'
task :create_files do
  %W[artifacts/cucumber_json_reports/run.json artifacts/cucumber_json_reports/rerun.json artifacts/final_test_reports/final_cucumber_json_report.json artifacts/final_test_reports/run_results_with_case_id.json artifacts/final_test_reports/rerun_results_with_case_id.json artifacts/final_test_reports/test_cases.json].each do |file_name|
    File.open(file_name, 'w') do |file|
      file.puts '[]'
    end
  end
  File.open('artifacts/final_test_reports/final_junit_report.xml', 'w') do |file|
    xml_structure.each do |line|
      file.puts line
    end
  end
end

desc 'Saving Test cases from remote TestRail project'
task :store_cases_titles do
  @client = TestRail::APIClient.new(DROMEDARY['testrail']['url'])
  @client.user = DROMEDARY['testrail']['user']
  @client.password = DROMEDARY['testrail']['password']

  project_id = DROMEDARY['testrail']['project_id']
  suite_id = DROMEDARY['testrail']['suite_id']
  cases = @client.get_cases_for_suite(project_id, suite_id)
  @full_cases = @client.get_cases_titles(cases, project_id, suite_id)

  File.open('artifacts/final_test_reports/test_cases.json', 'w') do |file|
    require 'json'
    file.puts @full_cases.to_json
  end
end

# Runner tasks

desc 'Run Cucumber features for the first run'
task :run_cucumber do
  sh "cucumber -p junit_report -p rerun_formatter -p run_json_report" do
    #ignore errors
  end
end

desc 'Rerun Cucumber features according to the fails.log'
task :rerun_failed do
  sh "cucumber @artifacts/final_test_reports/fails.log -p junit_report -p rerun_json_report" do
    #ignore errors
  end
end

task :rerun_if_needed do
  if File.file?("artifacts/final_test_reports/fails.log")
    if File.read("artifacts/final_test_reports/fails.log").empty?
      puts 'Rerun step skipped, no fails occurred during the first run'
    else
      fails = File.read("artifacts/final_test_reports/fails.log")

      File.open('artifacts/final_test_reports/fails.log', 'w') do |file|
        file.puts fails.gsub('\n', ' ')
      end

      sh "rake rerun_and_update_reports" do
        #ignore errors
      end
    end
  else
    puts 'Rerun step skipped, no fails occurred during the first run'
  end
end

desc 'Rerun failed Cucumber features and update respective reports'
task :rerun_and_update_reports do
  %W[clean_interim_reports rerun_failed merge_junit_reports get_case_ids[rerun]].each do |task_name|
    sh "rake #{task_name}" do
      #ignore errors
    end
  end
end

# Cleaning tasks

desc 'Cleaning all interim reports'
task :clean_interim_reports do
  %W[clean_test_rail clean_junit].each do |task_name|
    sh "rake #{task_name}" do
      #ignore errors
    end
  end
end

desc 'Cleaning interim TestRail reports'
task :clean_test_rail do
  catalog = 'artifacts/testrail_reports'
  files = Dir.entries(catalog).delete_if { |entry| File.directory?(entry) }
  files.map! { |f| "#{catalog}/#{f}" }
  rm files
end

desc 'Cleaning interim JUnit reports'
task :clean_junit do
  catalog = 'artifacts/junit_xml_reports'
  files = Dir.entries(catalog).delete_if { |entry| File.directory?(entry) }
  files.map! { |f| "#{catalog}/#{f}" }
  rm files
end

desc 'Cleaning interim Cucumber JSON reports'
task :clean_cucumber_json do
  catalog = 'artifacts/cucumber_json_reports'
  files = Dir.entries(catalog).delete_if { |entry| File.directory?(entry) }
  files.map! { |f| "#{catalog}/#{f}" }
  rm files
end

desc 'Cleaning rudimentary folders'
task :clean_folders do
  %W[artifacts/cucumber_json_reports artifacts/junit_xml_reports artifacts/testrail_reports].each do |dir_name|
    sh "rmdir #{dir_name}" do
      #ignore errors
    end
  end
end

desc 'Cleaning project tree from unnecessary files and folders'
task :final_clean_ups do
  %W[clean_test_rail clean_junit clean_cucumber_json clean_folders].each do |task_name|
    sh "rake #{task_name}" do
      #ignore errors
    end
  end
end

# Report generation tasks

desc 'Merging interim JUnit reports to final JUnit report'
task :merge_junit_reports do
  file_names = Dir.entries('artifacts/junit_xml_reports').delete_if { |entry| File.directory?(entry) }
  file_names.each do |file_name|
    sh "junit_merge artifacts/junit_xml_reports/#{file_name} artifacts/final_test_reports/final_junit_report.xml" do
      #ignore errors
    end
  end
end

desc 'Merging interim Cucumber json reports to final Cucumber json report'
task :generate_cucumber_json_reports do
  test_results = []

  run_results = JSON.parse(File.read('artifacts/cucumber_json_reports/run.json'))
  rerun_results = JSON.parse(File.read('artifacts/cucumber_json_reports/rerun.json'))

  run_results.each do |x|
    rerun_results.each do |y|
      if y.values[0] == x.values[0]
        x.merge!(y)
      end
    end
    test_results.push(x)
  end

  File.open('artifacts/final_test_reports/final_cucumber_json_report.json', 'w') do |file|
    require 'json'
    file.puts test_results.to_json
  end
end

desc 'Generating interim TestRail report for a particular run'
task :get_case_ids, :run_type do |task, args|
  @test_results = {}
  file = File.read('artifacts/final_test_reports/test_cases.json')
  @full_cases = JSON.parse(file)

  file_names = Dir.entries('artifacts/testrail_reports').delete_if { |entry| File.directory?(entry) }
  file_names.each do |file_name|
    result = JSON.parse(File.read("artifacts/testrail_reports/#{file_name}"))
    @test_results.update(result)
  end

  @results_json = []
  @test_results.map do |full_desc,status_id|
    n = 0
    until n == status_id.count do
      current_result = {:case_id => find_id(full_desc)[n], :status_id => status_id[n] } if find_id(full_desc)
      @results_json.push(current_result)
      n += 1
    end
  end

  @results_json.compact!
  File.open("artifacts/final_test_reports/#{args[:run_type]}_results_with_case_id.json", 'w') do |file|
    file.write(@results_json.to_json)
  end
end

desc 'Creating Test Run on remote TestRail project'
task :create_run, :suite_type, :environment, :section_name do |task, args|
  @client = TestRail::APIClient.new(DROMEDARY['testrail']['url'])
  @client.user = DROMEDARY['testrail']['user']
  @client.password = DROMEDARY['testrail']['password']
  project_id = DROMEDARY['testrail']['project_id']
  suite_id = DROMEDARY['testrail']['suite_id']

  test_run_name =  DROMEDARY['testrail']['test_run_default_name'] + ' ' + args[:suite_type].capitalize + ' on ' + args[:environment].capitalize
  test_run = @client.add_run(project_id, suite_id, test_run_name)
  file = File.open('artifacts/final_test_reports/test_run_id.txt', File::CREAT|File::TRUNC|File::RDWR)
  file.puts test_run['id']
  file.close
end

desc 'Closing Test Run on remote TestRail project'
task :close_run, :environment do
  @client = TestRail::APIClient.new(DROMEDARY['testrail']['url'])
  @client.user = DROMEDARY['testrail']['user']
  @client.password = DROMEDARY['testrail']['password']

  run_results = JSON.parse(File.read('artifacts/final_test_reports/run_results_with_case_id.json'))
  rerun_results = JSON.parse(File.read('artifacts/final_test_reports/rerun_results_with_case_id.json'))
  test_results = run_results + rerun_results

  run_id = File.new('artifacts/final_test_reports/test_run_id.txt').read.chomp
  @client.add_results_for_cases(run_id, test_results)
  @client.mark_untested_tests_failed(run_id)
  @client.close_run(run_id, data = {})
end

# METHODS

def xml_structure
  ['<?xml version="1.0" encoding="UTF-8"?>',
   '<testsuite name="" tests="" failures="" errors="" time="" timestamp="">',
   '  <!-- Randomized with seed 00000 -->',
   '  <properties/>',
   '</testsuite>']
end

def find_id(full_title)
  @ids_array = []
  @full_cases.select {|c| c['title'] == full_title.gsub('  ', ' ')}.each do |e|
    @ids_array << e['id']
  end
  @ids_array unless @ids_array.empty?
end