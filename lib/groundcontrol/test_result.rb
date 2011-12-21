require "nokogiri"

module GroundControl
  
  class TestResult
    
    attr_reader :name, :message
    
    def self.read_from_directory(path_to_tests)
      test_results_in_directory = []
      
      Dir.chdir(path_to_tests)
      Dir.glob("TEST-*.xml").each do |file|
        f = File.open(File.join(path_to_tests, file))
        doc = Nokogiri::XML(f)
        f.close()
        test_results_in_directory += read_tests_from_xml_document(doc)
      end
      
      return test_results_in_directory
    end
    
    def self.read_from_xml(xml_string)
      doc = Nokogiri::XML.parse(xml_string)
      
      return read_tests_from_xml_document(doc)
    end
    
    def self.read_tests_from_xml_document(doc)
      tests = []
      
      doc.xpath('//testcase').each do |testcase|
        failure = testcase.xpath('//failure')
        if failure.blank?
          tests << TestResult.new(testcase['name'])
        else
          tests << TestResult.new(testcase['name'], failure.first.content)
        end
      end
      
      
      return tests
    end
    
    def initialize(name, failure_message = nil)
      @name = name      
      @failed = false
      
      if failure_message
        @failed = true
        @message = failure_message
      end
    end
    
    def failed?
      return @failed
    end
    
    def success?
      return true if not @failed
    end
    
  end
  
end