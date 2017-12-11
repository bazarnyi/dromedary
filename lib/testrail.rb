#
# TestRail API binding for Ruby (API v2, available since TestRail 3.0)
#
# Learn more:
#
# http://docs.gurock.com/testrail-api2/start
# http://docs.gurock.com/testrail-api2/accessing
#
# Copyright Gurock Software GmbH. See license.md for details.
#

require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module TestRail
  class APIClient
    @url = ''
    @user = ''
    @password = ''

    attr_accessor :user
    attr_accessor :password

    def initialize(base_url)
      if !base_url.match(/\/$/)
        base_url += '/'
      end
      @url = base_url + 'index.php?/api/v2/'
    end

    def add_run(project_id, suite_id, test_run_name, section_id=nil)
      cases_ids = section_id ? get_all_cases(project_id, suite_id, section_id) : get_cases_for_suite(project_id, suite_id).map {|item| item['id']}
      data = {'suite_id'=> suite_id, 'name' => test_run_name,'include_all'=>false, 'case_ids' => cases_ids }
      send_post("add_run/#{project_id}", data)
    end

    def get_all_cases(project_id, suite_id, section_id)
      all_sections = get_all_inherited_sections(project_id, suite_id, section_id)
      cases_ids = []
      all_sections.uniq!
      all_sections.each do |section|
        cases_ids += get_cases_for_section(project_id, suite_id, section)
      end
      cases_ids
    end

    def get_cases_for_suite(project_id, suite_id)
      send_get("get_cases/#{project_id}&suite_id=#{suite_id}")
    end

    def get_cases_for_section(project_id, suite_id, section_id)
      send_get("get_cases/#{project_id}&suite_id=#{suite_id}&section_id=#{section_id}").map {|item| item['id']}
    end

    def get_all_inherited_sections(project_id, suite_id, section_id)
      hash = sections_hash(project_id, suite_id)
      to_preceed = hash['entries'].find{|el| el['id'] == section_id}
      results = []
      get_entries_array to_preceed, results
      results.map { |el| el['id']}
    end

    def get_cases_titles(cases, project_id, suite_id)
      sections = get_sections(project_id, suite_id)
      full_cases = []
      cases.each do |c|
        c['title'] = full_title(c, sections)
        full_cases << c
      end

      full_cases
    end

    def add_results_for_cases(run_id, test_rail_results)
      data = {}
      data[:results] = test_rail_results
      send_post("add_results_for_cases/#{run_id}", data)
    end

    def full_title(case_hash, sections)
      parent_section_id = case_hash['section_id']
      results = []
      section = sections.find do |sec|
        sec['id'] == parent_section_id
      end

      get_full_sections_title_for(section, sections, results)
      results.push(case_hash['title']).join(' ')
    end

    def get_section(section_id)
      send_get("get_section/#{section_id}")
    end

    def get_full_sections_title_for(section, sections, results)
      results.unshift(section['name'])
      unless section['depth'] == 0
        parent_section = parent_section(section, sections)
        get_full_sections_title_for(parent_section, sections, results)
      end
    end


    def get_entries_array(node, results)
      results << node
      node['entries'].each do |entry|
        results << entry
        unless entry['entries'].empty?
          get_entries_array(entry, results)
        end
      end
    end

    def parent_section(section, sections)
      sections.find { |sec| sec['id'] == section['parent_id'] }
    end

    def build_hash(node, array)
      nodes_to_proceed = array.select do |section|
        section['parent_id'] == node['id']
      end

      nodes_to_proceed.each do |n|
        node['entries'] << n
        array.delete n
        build_hash(n, array)
      end
    end


    def sections_hash(project_id, suite_id)
      all_sections = get_sections(project_id, suite_id)
      all_sections.map! {|el| el['entries'] =[]; el}
      main = all_sections.find {|el| el['depth'] == 0}
      all_sections.delete(main)
      build_hash(main, all_sections)
      main
    end

    def get_section_id(project_id, suite_id, section_title)
      all_sections = get_sections(project_id, suite_id)
      all_sections.find{|section| section['name'] == section_title}['id']
    end

    def get_sections(project_id, suite_id)
      send_get("get_sections/#{project_id}&suite_id=#{suite_id}")
    end

    def add_result_for_case(run_id, case_id, data)
      send_post("add_result_for_case/#{run_id}/#{case_id}", data)
    end

    def close_run(run_id, data)
      send_post("close_run/#{run_id}", data)
    end

    def mark_untested_tests_failed(run_id)
      tests = get_untested_tests(run_id)
      return if tests.empty?
      tests_ids = tests.map {|t| t['id']}
      mark_failed_tests_for_run(run_id, tests_ids)
    end

    def add_milestone(project_id, ms_name)
      data = {"name"=> ms_name + Time.now.strftime("_%H/%M/%S_%d/%m/%Y")}
      response = send_post("add_milestone/#{project_id}", data)
      response['id']
    end

    def close_milestone(ms_id)
      data = {'is_completed' => true}
      send_post("update_milestone/#{ms_id}", data)
    end

    def mark_failed_tests_for_run(run_id, tests_ids)
      data = {}
      data['results'] = []
      tests_ids.each do |id|
        data['results'] << {'test_id'=>id, 'status_id'=>5}
      end
      send_post("add_results/#{run_id}", data)
    end

    def get_untested_tests(run_id)
      send_get("get_tests/#{run_id}&status_id=3")
    end


    #
    # Send Get
    #
    # Issues a GET request (read) against the API and returns the result
    # (as Ruby hash).
    #
    # Arguments:
    #
    # uri                 The API method to call including parameters
    #                     (e.g. get_case/1)
    #
    def send_get(uri)
      _send_request('GET', uri, nil)
    end

    #
    # Send POST
    #
    # Issues a POST request (write) against the API and returns the result
    # (as Ruby hash).
    #
    # Arguments:
    #
    # uri                 The API method to call including parameters
    #                     (e.g. add_case/1)
    # data                The data to submit as part of the request (as
    #                     Ruby hash, strings must be UTF-8 encoded)
    #
    def send_post(uri, data)
      _send_request('POST', uri, data)
    end

    private
    def _send_request(method, uri, data)
      url = URI.parse(@url + uri)
      if method == 'POST'
        request = Net::HTTP::Post.new(url.path + '?' + url.query)
        request.body = JSON.dump(data)
      else
        request = Net::HTTP::Get.new(url.path + '?' + url.query)
      end
      request.basic_auth(@user, @password)
      request.add_field('Content-Type', 'application/json')

      conn = Net::HTTP.new(url.host, url.port)
      if url.scheme == 'https'
        conn.use_ssl = true
        conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      response = conn.request(request)

      if response.body && !response.body.empty?
        result = JSON.parse(response.body)
      else
        result = {}
      end

      if response.code != '200'
        if result && result.key?('error')
          error = '"' + result['error'] + '"'
        else
          error = 'No additional error message received'
        end
        raise APIError.new('TestRail API returned HTTP %s (%s)' %
                               [response.code, error])
      end

      result
    end
  end

  class APIError < StandardError
  end
end