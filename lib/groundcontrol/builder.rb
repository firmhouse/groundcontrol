require 'rubygems'
require 'git'
require 'grit'
require 'open3'
require 'net/http'

module GroundControl
  
  class Builder
    
    attr_reader :output
    
    def initialize(project_name, config)      
      @project_name = project_name
      @config = config
      
      @workspace = File.expand_path(File.join("builds", project_name))
      
      @build_directory = File.join(@workspace, "build")
      @reports_directory = File.join(@workspace, "reports")
      @git_url = @config['git']
      
      @output = ""
    end
  
    def build
      create_workspace
      clone_repository
      prepare_build_environment
      run_tests_and_report
    end
    
    private
    
    def start_virtual_screen
      ENV['DISPLAY'] = ":5"
      
      xvfb_pid = fork do
        Open3.popen3('Xvfb :5 -ac -screen 0 1024x768x8') do |input, output, err, thread|
          @output += output.read
          @output += err.read
        end
      end
    end
    
    def run_unit_tests()
      
      Open3.popen3("cd #{@build_directory}; rvm rvmrc load; source \"$HOME/.rvm/scripts/rvm\"; bundle exec rake ci:setup:testunit test") do |input, output, err, thread| 
        @output += output.read 
        @output += err.read
      end
      
    end
    
    def run_cucumber_tests()
      screen_pid = start_virtual_screen()
      
      ENV['CUCUMBER_OPTS'] = "--format junit --out ../reports/features"
      
      Open3.popen3("cd #{@build_directory}; rvm rvmrc load; source \"$HOME/.rvm/scripts/rvm\"; bundle exec rake cucumber") do |input, output, err, thread| 
        @output += output.read
        @output += err.read
      end
      
      Process.kill "TERM", screen_pid
    end
    
    def run_tests_and_report()
      run_unit_tests()
      run_cucumber_tests()
      
      report = BuildReport.new(
        @project_name, 
        @repository.head.name, 
        @repository.commits.first)
        
      if File.exists?(File.join(@reports_directory, "features"))
        report.test_results += TestResult.read_from_directory(File.join(@reports_directory, "features"))
      end

      if File.exists?(File.join(@build_directory, "test", "reports"))
        report.test_results += TestResult.read_from_directory(File.join(@build_directory, "test", "reports"))
      end
      
      return report
    end

    def clone_repository
      grit = Grit::Git.new('/tmp/grit-fill')
      grit.clone({:quiet => false, :verbose => true, :progress => true}, @git_url, @build_directory)

      @repository = Grit::Repo.new(@build_directory)
    end

    def create_workspace
      FileUtils.rm_rf @workspace

      FileUtils.mkdir_p(@workspace)
      FileUtils.mkdir_p(@build_directory)
      FileUtils.mkdir_p(@reports_directory)
    end

    def initialize_rvm
      IO.popen("cd #{@build_directory}; rvm rvmrc trust #{@build_directory}") { |io| @output += io.read }
    end

    def install_bundler_gems()
      IO.popen("cd #{@build_directory}; rvm rvmrc load; source \"$HOME/.rvm/scripts/rvm\"; bundle install --without production", "r") { |io| @output += io.read }
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
      IO.popen("cd #{@build_directory}; rvm rvmrc load; source \"$HOME/.rvm/scripts/rvm\"; bundle exec rake db:schema:load") { |io| @output += io.read }
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
    
    def inject_ci_reporter
      ENV['CI_REPORTS'] = File.join(@reports_directory, "testunit")
      
      ci_reporter_config = "require 'ci/reporter/rake/test_unit'"

      File.open("#{@build_directory}/lib/tasks/ci_reporter.rake", 'w') { |f| f.write(ci_reporter_config) }
    end

    def prepare_build_environment    
      ENV['RAILS_ENV'] = "test"

      initialize_rvm()
      install_bundler_gems()
      
      setup_database()
      
      inject_ci_reporter()
      inject_thinking_sphinx_config()
    end
  
  end

end
