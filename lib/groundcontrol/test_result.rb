require "nokogiri"

module GroundControl
  
  class TestResult
    
    attr_reader :name, :message, :suite
    
    def self.read_from_directory(path_to_tests, suite = nil)
      test_results_in_directory = []
      
      Dir.chdir(path_to_tests)
      Dir.glob("TEST-*.xml").each do |file|
        f = File.open(File.join(path_to_tests, file))
        doc = Nokogiri::XML(f)
        f.close()
        test_results_in_directory += read_tests_from_xml_document(doc, suite = nil)
      end
      
      return test_results_in_directory
    end
    
    def self.read_from_xml(xml_string)
      doc = Nokogiri::XML.parse(xml_string)
      
      return read_tests_from_xml_document(doc)
    end
    
    def self.read_tests_from_xml_document(doc, suite = nil)
      tests = []
      
      doc.xpath('//testcase').each do |testcase|
        failure = testcase.xpath('//failure')
        if failure.empty?
          tests << TestResult.new(testcase['name'], suite)
        else
          tests << TestResult.new(testcase['name'], suite, failure.first.content)
        end
      end
      
      
      return tests
    end
    
    def initialize(name, suite = nil, failure_message = nil)
      @name = name
      @failed = false
      @suite = suite
      
      if failure_message
        @failed = true
        @message = failure_message
      end
    end
    
    def failed?
      return @failed
    end
    
    def success?
      !failed?
    end
    
  end
  
end