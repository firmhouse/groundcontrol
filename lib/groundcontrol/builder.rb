require 'rubygems'
require 'git'
require 'tinder'
require 'grit'
require 'net/http'
require 'geckoboard-push'

module GroundControl
  
  class Build
    
    def initialize(project_name, config)
      @project_name = project_name
      @config = config
    end
  
    def build
      @git_repo = @config['git']
      
      setup_workspace()
      
      @repository = setup_build_directory()
      
      last_commit_author = @repository.commits.first.author
      
      notify_campfire_of_build_started(@project_name, @repository.head.name, last_commit_author.name)
      
      install_environment()
      
      test_report = run_tests_and_report()
      
      notify_geckoboard_of_build_result(test_report)
      notify_campfire_of_build_result(test_report, @project_name, @repository.head.name, last_commit_author.name)
      
      return test_report
    end
    
    private
    
    def start_virtual_screen
      ENV['DISPLAY'] = ":5"
      
      xvfb_pid = fork do
        exec 'Xvfb :5 -ac -screen 0 1024x768x8'
      end
    end
    
    def notify_geckoboard_of_build_result(report)
      Geckoboard::Push.api_key = @config['geckoboard']['api_key']
      widget = Geckoboard::Push.new(@config['geckoboard']['widget'])
      if report.failed?
        widget.text([{:text => "#{report.commit.author.name} is a loser and broke the build for #{report.project_name}.", :type => :alert}])
      else
        widget.text([{:text => "#{report.commit.author.name} is awesome and made some well-crafted code for #{report.project_name}"}])
      end
    end
    
    def notify_campfire_of_build_result(test_report, project_name, branch_name, author_name)
      campfire_config = @config['campfire']

      campfire = Tinder::Campfire.new campfire_config['subdomain'], :token => campfire_config['token']
      room = campfire.find_room_by_name(campfire_config['room'])
      
      if test_report.success?
        room.speak "Build SUCCEEDED. +1 for #{author_name}."
      else
        room.speak "Build FAILED for #{project_name}/#{branch_name} #{@config['github']}/commit/#{test_report.commit.sha}. #{author_name} is definitely not the best developer."
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
      
      Process.kill "QUIT", screen_pid
      
      
      return cucumber_status
    end
    
    def run_tests_and_report()
      testunit_return_code = run_unit_tests()
      #cucumber_return_code = run_cucumber_tests()
      cucumber_return_code = 345
      
      return BuildReport.new(@project_name, @repository.head.name, testunit_return_code == 0, cucumber_return_code == 0, @repository.commits.first)
    end

    def setup_build_directory
      Git.clone(@git_repo, @build_directory)
      return Grit::Repo.new(@build_directory)
    end

    def setup_workspace
      FileUtils.rm_rf File.join("builds/", @project_name)

      @build_directory = File.join("builds/", @project_name, "build")
      @reports_directory = File.join("builds/", @project_name, "reports")

      FileUtils.mkdir_p(@build_directory)
      FileUtils.mkdir_p(@reports_directory)
    end

    def notify_campfire_of_build_started(project_name, branch_name, author_name)
      campfire_config = @config['campfire']

      campfire = Tinder::Campfire.new campfire_config['subdomain'], :token => campfire_config['token']
      room = campfire.find_room_by_name(campfire_config['room'])

      room.speak "Build started for #{project_name}/#{branch_name} by #{author_name}."
    end

    def initialize_rvm
      system "cd #{@build_directory}; rvm rvmrc trust"
      system "cd #{@build_directory}; rvm reload"
    end

    def install_bundler_gems()
      system "cd #{@build_directory}; bundle install --without production"
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

    def install_environment    
      ENV['RAILS_ENV'] = "test"

      initialize_rvm()
      install_bundler_gems()
      inject_ci_reporter()
      
      setup_database()
      inject_thinking_sphinx_config()
    end
  
  end

end