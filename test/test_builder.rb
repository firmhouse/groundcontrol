require 'test/unit'
require 'mocha'
require 'groundcontrol'
require 'fileutils'
require 'active_support'

module GroundControl
  
  class BuilderTest < Test::Unit::TestCase
    
    def setup
      if File.exists?(File.expand_path("builds/cool_rails_project"))
        FileUtils.rm_r(File.expand_path("builds/cool_rails_project"))
      end
      @builder = Builder.new("cool_rails_project", {"git" => "test/repositories/dot_git_rails"})
    end

    def test_build_creates_workspace_directories
      @builder.stubs('clone_repository')
      @builder.stubs('prepare_build_environment')
      @builder.stubs('run_tests_and_report')
      
      @builder.build
      
      assert File.exists?(File.expand_path("builds/cool_rails_project")), "Expected directory builds/cool_rails_project to exist."
      assert File.exists?(File.expand_path("builds/cool_rails_project/reports")), "Expected directory builds/cool_rails_project/reports to exist."
      assert File.exists?(File.expand_path("builds/cool_rails_project/build")), "Expected directory builds/cool_rails_project/build to exist."      
    end
    
    def test_build_clones_the_repository
      @builder.stubs('create_workspace')
      @builder.stubs('prepare_build_environment')
      @builder.stubs('run_tests_and_report')
      
      @builder.build
      
      FileUtils.mkdir_p(File.expand_path("builds/cool_rails_project/reports"))
      FileUtils.mkdir_p(File.expand_path("builds/cool_rails_project/build"))
      
      assert File.exists?(File.expand_path("builds/cool_rails_project/build/README"))
    end
    
    def test_build_installs_bundle      
      FileUtils.mkdir_p(File.expand_path("builds/cool_rails_project/reports"))
      FileUtils.mkdir_p(File.expand_path("builds/cool_rails_project/build"))
      
      @builder.stubs('create_workspace')
      @builder.stubs('run_tests_and_report')
      @builder.stubs('setup_database')
      
      @builder.build
      
      assert File.exists?(File.expand_path("builds/cool_rails_project/build/.bundle")), "Expected .bundle file in build directory"
    end
    
    def test_build_sets_up_the_database
      @builder.stubs('run_tests_and_report')
      @builder.stubs('inject_ci_reporter')
      
      @builder.build
      
      assert File.exists?("builds/cool_rails_project/build/config/database.yml")
    end
    
    def test_build_injects_ci_reporter
      @builder.stubs('setup_database')
      @builder.stubs('run_tests_and_report')
      
      @builder.build
      
      assert File.exists?(File.expand_path("builds/cool_rails_project/build/lib/tasks/ci_reporter.rake")), "Expected ci_reporter.rake to be created"
      
      file = File.open(File.expand_path("builds/cool_rails_project/build/lib/tasks/ci_reporter.rake"))
      contents = file.read
      file.close
      puts contents
      
      assert_match /test_unit/, contents, "Expected ci reporter rake task to include test_unit"
    end
    
    def test_build_injects_thinking_sphinx_config
      @builder.stubs('setup_database')
      @builder.stubs('run_tests_and_report')
      
      @builder.build
      
      assert File.exists?(File.expand_path("builds/cool_rails_project/build/config/sphinx.yml")), "Expected sphinx.yml to be in build/config"
    end
    
    def test_build_runs_test_unit
      @builder.stubs('inject_thinking_sphinx_config')
      @builder.stubs('run_cucumber_tests')
      
      pwd_before = Dir.pwd
      
      @builder.build
      
      Dir.chdir(pwd_before)
      
      assert File.exists?(File.expand_path("builds/cool_rails_project/reports/testunit/TEST-PersonTest.xml")), "Expected TEST-PersonTest.xml reports to exist in reports/testunit/TEST-PersonTest.xml"
    end
    
    def test_build_runs_cucumber
      @builder.stubs('inject_thinking_sphinx_config')
      @builder.stubs('run_unit_tests')
      
      pwd_before = Dir.pwd
      
      @builder.build
      
      Dir.chdir(pwd_before)
      
      assert File.exists?(File.expand_path("builds/cool_rails_project/reports/features")), "Expected builds/cool_rails_project/reports/features to exist."
    end
    
    def test_build_generates_report
      @builder.stubs('prepare_build_environment')
      @builder.stubs('run_unit_tests')
      @builder.stubs('run_cucumber_tests')
      
      report = @builder.build
      
      assert_not_nil report.commit
    end
    
    def test_build_should_report_command_errors
      # TODO: This test should make sure we catch command errors and save them somewhere in the build report.
    end

  end
  
end