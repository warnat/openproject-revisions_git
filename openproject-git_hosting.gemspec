# encoding: UTF-8
$:.push File.expand_path("../lib", __FILE__)

require 'open_project/git_hosting/version'
# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-git_hosting"
  s.version     = OpenProject::GitHosting::VERSION
  s.authors     = "Oliver Günther"
  s.email       = "mail@oliverguenther.de"
  s.homepage    = "https://www.github.com/oliverguenther/openproject-git_hosting"
  s.summary     = 'OpenProject Git Hosting'
  s.description = "This plugin allows straightforward management of Gitolite within OpenProject."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(README.md)

  s.add_dependency "rails", "~> 3.2.14"
  
  s.add_dependency "lockfile"
  s.add_dependency "gitolite-rugged"

end
