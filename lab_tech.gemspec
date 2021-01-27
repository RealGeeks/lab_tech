$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "lab_tech/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "lab_tech"
  spec.version     = LabTech::VERSION
  spec.authors     = ["Sam Livingston-Gray"]
  spec.email       = ["geeksam@gmail.com"]
  spec.homepage    = "https://github.com/RealGeeks/lab_tech"
  spec.summary     = "Tools for using GitHub's 'Scientist' library with ActiveRecord, for those of us not operating apps at ROFLscale"
  spec.description = "Tools for using GitHub's 'Scientist' library with ActiveRecord, for those of us not operating apps at ROFLscale"
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  spec.test_files = Dir["spec/**/*"]

  spec.add_dependency "rails",     "~> 5.1"
  spec.add_dependency "scientist", "~> 1.3"

  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "rspec-rails", "~> 4.0"
  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "table_print"
end
