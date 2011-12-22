module GroundControl
  
  class BuildReport
    
    attr_reader :project_name, :branch, :commit
    attr_accessor :test_results
    
    def initialize(project_name, branch, commit)
      @project_name = project_name
      @branch = branch
      @commit = commit
      @test_results = []
    end
    
    def success?
      testunit_success && cucumber_success
    end
    
    def failed?
      !success?
    end
    
  end
  
end