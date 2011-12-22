require 'test/unit'
require 'groundcontrol'

module GroundControl
  
  class BuildReportTest < Test::Unit::TestCase
    
    def test_report_failed_with_at_least_one_failing_test
      report = BuildReport.new('project', 'master', nil)
      report.test_results << TestResult.new('name_of_failing_test', 'this is a failure message')
      report.test_results << TestResult.new('name_of_passed_test')
      
      assert report.failed?
    end
    
    def test_report_not_failed_with_successful_tests
      report = BuildReport.new('project', 'master', nil)
      report.test_results << TestResult.new('name_of_passed_test')
      
      assert !report.failed?
    end
    
    def test_report_success_with_successful_tests
      report = BuildReport.new('project', 'master', nil)
      report.test_results << TestResult.new('name_of_passed_test')
      
      assert report.success?
    end
    
  end
  
end