require 'rubygems'
require 'git'
require 'tinder'
require 'grit'
require 'net/http'

module GroundControl
  
  class Builder
    
    def initialize(project_name, config)
      @project_name = project_name
      @config = config
      @workspace = File.expand_path(File.join("builds", project_name))
      puts "Workspace: #{@workspace}"
      @build_directory = File.join(@workspace, "build")
      @reports_directory = File.join(@workspace, "reports")
      @git_url = @config['git']
    end
  
    def build
      create_workspace()
      
      clone_repository()
      
      prepare_build_environment()
      
      test_report = run_tests_and_report()
      
      notify_campfire_of_build_result(test_report, @project_name, @repository)
      
      return test_report
    end
    
    private
    
    def notify_campfire_of_build_result(test_report, project_name, repository)
      campfire_config = @config['campfire']
 
      campfire = Tinder::Campfire.new campfire_config['subdomain'], :token => campfire_config['token']
      room = campfire.find_room_by_name(campfire_config['room'])
      
      last_commit = repository.commits.first
      
      if test_report.success?
        room.speak "Build SUCCEEDED. +1 for #{last_commit.author.name}."
      else
        room.speak "Build FAILED for #{project_name}/#{repository.head.name} #{@config['github']}/commit/#{test_report.commit.sha}. #{last_commit.author.name} is definitely not the best developer."
      end
    end
    
    def start_virtual_screen
      ENV['DISPLAY'] = ":5"
      
      xvfb_pid = fork do
        exec 'Xvfb :5 -ac -screen 0 1024x768x8'
      end
    end
    
    def run_unit_tests()
      ENV['CI_REPORTS'] = "../reports/testunit"
      
      test_output = `cd #{@build_directory}; bundle exec rake ci:setup:testunit test`
      return $?.to_i
    end
    
    def run_cucumber_tests()
      screen_pid = start_virtual_screen()
      
      ENV['CUCUMBER_OPTS'] = "--format junit --out ../reports/features"

      cucumber_output = `cd #{@build_directory}; bundle exec rake cucumber`
      cucumber_status = $?.to_i
      
      Process.kill "TERM", screen_pid
      
      return cucumber_status
    end
    
    def run_tests_and_report()
      testunit_return_code = run_unit_tests()
      cucumber_return_code = run_cucumber_tests()
      
      report = BuildReport.new(
        @project_name, 
        @repository.head.name, 
        testunit_return_code == 0, 
        cucumber_return_code == 0, 
        @repository.commits.first)
        
      report.test_results += TestResult.read_from_directory(File.join(@reports_directory, "features"))
      report.test_results += TestResult.read_from_directory(File.join(@reports_directory, "testunit"))
      
      return report
    end

    def clone_repository
      Git.clone(@git_url, @build_directory)
      @repository = Grit::Repo.new(@build_directory)
    end

    def create_workspace
      FileUtils.rm_rf @workspace

      FileUtils.mkdir_p(@build_directory)
      FileUtils.mkdir_p(@reports_directory)
    end

    def initialize_rvm
      `cd #{@build_directory}; rvm rvmrc trust`
      `cd #{@build_directory}; rvm reload`
    end

    def install_bundler_gems()
      `cd #{@build_directory}; bundle install --without production`
    end

    def inject_ci_reporter()
      doc = <<EOF
require 'rubygems'
require 'ci/reporter/rake/test_unit' # use this if you're using Test::Unit
EOF

      File.open("#{@build_directory}/lib/tasks/ci_reporter.rake", 'w') { |f| f.write(doc) }
    end

    def inject_database_config()

      database = <<EOF
test: &test
  adapter: mysql2
  encoding: utf8
  reconnect: false
  database: #{@project_name}_test
  pool: 5
  username: root
  password:

  cucumber:
    <<: *test
EOF

      File.open("#{@build_directory}/config/database.yml", 'w') { |f| f.write(database) }

    end

    def load_empty_schema()
      system "cd #{@build_directory}; bundle exec rake db:schema:load"
    end

    def setup_database()
      inject_database_config()
      load_empty_schema()
    end

    def inject_thinking_sphinx_config
      sphinx_config = <<EOF
test:
  port: 9312
EOF

      File.open("#{@build_directory}/config/sphinx.yml", 'w') { |f| f.write(sphinx_config) }
    end

    def prepare_build_environment    
      ENV['RAILS_ENV'] = "test"

      initialize_rvm()
      install_bundler_gems()
      inject_ci_reporter()
      
      setup_database()
      inject_thinking_sphinx_config()
    end
  
  end

end
