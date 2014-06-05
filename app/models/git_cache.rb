class GitCache < ActiveRecord::Base
  unloadable

  attr_accessible :command, :command_output, :project_identifier
end
