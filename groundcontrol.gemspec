Gem::Specification.new do |s|
  s.name = 'groundcontrol'
  s.version = '0.0.2'
  s.date = '2011-12-15'
  s.executables << 'groundcontrol'
  s.summary = 'Runs automated Rails tests and reports back.'
  s.description = 'Groundcontrol powers test builds for Rails projects'
  s.authors = ["Michiel Sikkes"]
  s.email = "michiel@firmhouse.com"
  s.files = [
    "lib/groundcontrol.rb", 
    "lib/groundcontrol/builder.rb", 
    "lib/groundcontrol/build_report.rb", 
    "lib/groundcontrol/test_result.rb"
  ]
  s.homepage = "http://github.com/Firmhouse/groundcontrol"
  
  s.add_runtime_dependency "grit"
  s.add_runtime_dependency "git"
  s.add_runtime_dependency "tinder"
  s.add_runtime_dependency "nokogiri"
end