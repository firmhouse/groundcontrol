module GroundControl
  
  class BuildReport
    
    attr_reader :project_name, :branch, :testunit_success, :cucumber_success, :commit
    
    def initialize(project_name, branch, testunit_success, cucumber_success, commit)
      @project_name = project_name
      @branch = branch
      @testunit_success = testunit_success
      @cucumber_success = cucumber_success
      @commit = commit
    end
    
    def success?
      testunit_success && cucumber_success
    end
    
    def failed?
      !success?
    end
    
  end
  
end