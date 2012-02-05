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
    
    def run_functional_tests()
      ENV['CI_REPORTS'] = File.join(@reports_directory, "testunit", "functionals")
      
      puts "-- FUNCTIONALS -> #{ENV['CI_REPORTS']}"
      
            
      Open3.popen3("bash -l -c \"cd #{@build_directory}; source .rvmrc; bundle exec rake ci:setup:testunit test:functionals\"") do |input, output, err, thread| 
        puts output.read
        command_output = output.read 
        command_err = err.read
        
        @output += command_err
        @output += command_output
      end
      
    end
    
    def run_unit_tests()
      ENV['CI_REPORTS'] = File.join(@reports_directory, "testunit", "units")
      
      puts "-- UNITS => #{ENV['CI_REPORTS']}"
      
      Open3.popen3("bash -l -c \"cd #{@build_directory}; source .rvmrc; bundle exec rake ci:setup:testunit test:units\"") do |input, output, err, thread| 
        puts output.read
        command_output = output.read 
        command_err = err.read
        
        @output += command_err
        @output += command_output
      end
      
    end
    
    def run_cucumber_tests()
      screen_pid = start_virtual_screen()
      
      ENV['CUCUMBER_OPTS'] = "--format junit --out ../reports/features"
      
      puts "-- CUCUMBER"
      
      Open3.popen3("bash -l -c \"cd #{@build_directory}; source .rvmrc; bundle exec rake cucumber\"") do |input, output, err, thread| 
        puts output.read
        command_output = output.read 
        command_err = err.read
        
        @output += command_err
        @output += command_output
      end
      
      Process.kill "TERM", screen_pid
    end
    
    def run_tests_and_report()
      report = BuildReport.new(
        @project_name, 
        @repository.head.name, 
        @repository.commits.first)
      
      run_functional_tests()
      run_unit_tests()
      run_cucumber_tests()
        
      if File.exists?(File.join(@reports_directory, "features"))
        report.test_results += TestResult.read_from_directory(File.join(@reports_directory, "features"), "cucumber")
      end
  
      if File.exists?(File.join(@reports_directory, "testunit", "functionals"))
        report.test_results += TestResult.read_from_directory(File.join(@reports_directory, "testunit", "functionals"), "functionals")
      end
      
      if File.exists?(File.join(@reports_directory, "testunit", "units"))
        report.test_results += TestResult.read_from_directory(File.join(@reports_directory, "testunit", "units"), "units")
      end
      
      return report
    end

    def clone_repository
      ENV['GIT_SSH'] = File.join(@workspace, 'ssh-wrapper')
      
      Git.clone(@git_url, @build_directory)

      @repository = Grit::Repo.new(@build_directory)
    end

    def create_workspace
      FileUtils.rm_rf @workspace

      FileUtils.mkdir_p(@workspace)
      FileUtils.mkdir_p(@build_directory)
      FileUtils.mkdir_p(@reports_directory)
      
      File.open("#{@workspace}/ssh-key", 'w') { |f| f.write(@config['private_key'])}
      
      ssh_wrapper = <<EOW
#!/bin/sh
ssh -o 'IdentityFile #{File.join(@workspace, "ssh-key")}' $*
EOW

      File.open("#{@workspace}/ssh-wrapper", 'w') { |f| f.write(ssh_wrapper) }
      FileUtils.chmod(0755, File.join(@workspace, "ssh-wrapper"))
    end

    def initialize_rvm
      # IO.popen("cd #{@build_directory}; rvm rvmrc trust #{@build_directory}") { |io| @output += io.read }
    end

    def install_bundler_gems()
      IO.popen("bash -l -c \"cd #{@build_directory}; source .rvmrc; bundle install --without production\"") { |io| puts io.read }
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
      IO.popen("bash -l -c \"cd #{@build_directory}; source .rvmrc; bundle exec rake db:schema:load\"") { |io| puts io.read }
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
