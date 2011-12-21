require 'test/unit'
require 'groundcontrol'

module GroundControl
  
  class TestResultTest < Test::Unit::TestCase
    
    def test_read_multiple_from_directory
      directory_with_test_files = File.expand_path("test/junit_results/")
      
      tests = GroundControl::TestResult.read_from_directory(directory_with_test_files)
      
      assert_equal 3, tests.size
    end
    
    def test_read_multiple_from_xml
      suite_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite errors="0" assertions="2" tests="2" skipped="0" time="0.329488" name="DeliveryAssigmentTest" failures="0">
        <testcase assertions="1" time="0.133832" name="test_first_test">
        </testcase>
        <testcase assertions="1" time="0.195365" name="test_to_csv_should_work_for_an_delivery_assignment_with_the_Transporter_GLS_selected">
        </testcase>
        <system-out>
        </system-out>
        <system-err>
        </system-err>
      </testsuite>
EOF

      test_cases = GroundControl::TestResult.read_from_xml(suite_xml)
      
      assert GroundControl::TestResult.new("test_first_test"), test_cases.first
      assert 2, test_cases.length
    end
    
    def test_read_success
      suite_xml = <<EOF
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuite errors="0" assertions="2" tests="2" skipped="0" time="0.329488" name="DeliveryAssigmentTest" failures="0">
              <testcase assertions="1" time="0.133832" name="test_first_test">
              </testcase>
              <system-out>
              </system-out>
              <system-err>
              </system-err>
            </testsuite>
EOF

      test_cases = GroundControl::TestResult.read_from_xml(suite_xml)
      
      assert_equal true, test_cases.first.success?
    end
    
    def test_read_failure_message
      suite_xml = <<EOT
      
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuite errors="0" failures="1" name="Supply info per project" skipped="0" tests="4" time="8.056938">
      <testcase classname="Supply info per project.Save purchase price on a product" name="Save purchase price on a product" time="1.513997">
      </testcase>
      <testcase classname="Supply info per project.Suppliers dropdown changed" name="Suppliers dropdown changed" time="2.785886">
      </testcase>
      <testcase classname="Supply info per project.Add new supplier" name="Add new supplier" time="2.416687">
        <failure message="failed Add new supplier" type="failed">
          <![CDATA[Scenario: Add new supplier

      Given a product
      Given I am logged in as a buyer
      When I edit the product
      And I follow "New supplier"
      And I fill in "Name" with "Nieuwe supplier"
      And I press "Create Supplier"
      Then I should see "Nieuwe supplier" within "#product_supplier_id"

      Message:
      ]]>
          <![CDATA[Element cannot be scrolled into view:http://127.0.0.1:33451/suppliers/new (Selenium::WebDriver::Error::MoveTargetOutOfBoundsError)
      (eval):2:in `send'
      (eval):2:in `click_link'
      ./features/step_definitions/web_steps.rb:35
      ./features/step_definitions/web_steps.rb:14:in `with_scope'
      ./features/step_definitions/web_steps.rb:34:in `/^(?:|I )follow "([^"]*)"(?: within "([^"]*)")?$/'
      features/supply_info_per_product.feature:29:in `And I follow "New supplier"']]>
        </failure>
      </testcase>
      <testcase classname="Supply info per project.Save the minimum required order amount for a product" name="Save the minimum required order amount for a product" time="1.340368">
      </testcase>
      </testsuite>
      
      
EOT

      test_cases = GroundControl::TestResult.read_from_xml(suite_xml)
      
      assert_equal true, test_cases[2].failed?
      assert_match /Element cannot be scrolled/, test_cases[2].message
    end
    
  end
  
end