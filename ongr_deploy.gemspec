$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "ongr_deploy/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "ongr_deploy"
  s.version     = OngrDeploy::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of OngrDeploy."
  s.description = "TODO: Description of OngrDeploy."
  s.license     = "MIT"

  s.files      = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "capistrano", "~> 3.1.0"

end
