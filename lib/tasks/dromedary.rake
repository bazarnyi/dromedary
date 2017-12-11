require 'nokogiri'
require 'yaml'
require_relative '../testrail'

DROMEDARY = YAML.load_file("#{Dir.pwd}/config/dromedary.yml")

# TASKS

# PREPARATION TASKS
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
    sh "mkdir #{dir_name}" do
      #ignore errors
    end
  end
end

desc 'This task creates and updates required files for reporting'
task :create_files do
  %W[artifacts/cucumber_json_reports/run.json artifacts/cucumber_json_reports/rerun.json artifacts/final_test_reports/final_cucumber_json_report.json artifacts/final_test_reports/run_with_ids.json artifacts/final_test_reports/rerun_with_ids.json artifacts/final_test_reports/test_cases.json].each do |file_name|
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

desc 'Saving Test cases from remote TestRail'
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

# METHODS
def xml_structure
  ['<?xml version="1.0" encoding="UTF-8"?>',
   '<testsuite name="" tests="" failures="" errors="" time="" timestamp="">',
   '  <!-- Randomized with seed 00000 -->',
   '  <properties/>',
   '</testsuite>']
end