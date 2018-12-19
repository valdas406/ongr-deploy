$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "ongr_deploy/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "ongr_deploy"
  s.version     = OngrDeploy::VERSION
  s.authors     = ["Voldemaras Kadys"]
  s.email       = "info@ongr.io"
  s.description = "Capistrano extension"
  s.summary     = "Capistrano extension for ONGR projects"
  s.license     = "MIT"
  s.homepage    = "https://github.com/ongr-io/ongr_deploy"
  s.files       = Dir["{bin,lib}/**/*", "LICENSE", "Rakefile", "README.rdoc"]
  s.executables = ['ongr']
  s.test_files  = Dir["test/**/*"]

  s.add_dependency "capistrano",      "~> 3.7.0"
  s.add_dependency "redis",           "~> 3.3.0"
  s.add_dependency "redis-namespace", "~> 1.5.0"
  s.add_dependency "aws-sdk",         "~> 2.6.0"
  s.add_dependency "deep_merge",      "~> 1.0.0"

end
