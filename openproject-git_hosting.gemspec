# encoding: UTF-8
$:.push File.expand_path("../lib", __FILE__)

require 'open_project/git_hosting/version'
# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-git_hosting"
  s.version     = OpenProject::GitHosting::VERSION
  s.authors     = "Finn GmbH"
  s.email       = "info@finn.de"
  s.homepage    = "https://www.openproject.org/projects/git-hosting"
  s.summary     = 'OpenProject Git Hosting'
  s.description = "This plugin allows straightforward management of Gitolite within OpenProject."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(CHANGELOG.md README.md)

  s.add_dependency "rails", "~> 3.2.14"
  
  s.add_dependency "lockfile"
  s.add_dependency "jbox-gitolite", "~> 1.1.11"
end
