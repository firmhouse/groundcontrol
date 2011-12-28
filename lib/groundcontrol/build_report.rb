module GroundControl
  
  class BuildReport
    
    attr_reader :project_name, :branch, :commit
    attr_accessor :test_results, :output
    
    def initialize(project_name, branch, commit)
      @project_name = project_name
      @branch = branch
      @commit = commit
      @test_results = []
    end
    
    def success?
      return !failed?
    end
    
    def failed?
      return true if @test_results.select { |t| t.failed? }.size > 0
      return false
    end
    
  end
  
end