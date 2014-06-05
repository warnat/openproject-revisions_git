require_dependency 'redmine/scm/adapters/git_adapter'

module OpenProject::GitHosting::Patches::GitAdapterPatch
  def self.included(base)
    base.class_eval do
      unloadable

      include InstanceMethods
      extend ClassMethods

      class << self
        alias_method_chain :scm_version_from_command_line, :git_hosting
      end

      alias_method_chain :scm_cmd, :git_hosting
    end
  end


  module ClassMethods

    def scm_version_from_command_line_with_git_hosting
      OpenProject::GitHosting::GitoliteWrapper.sudo_capture('git', '--version', '--no-color')
    end

  end


  module InstanceMethods

    private

    def scm_cmd_with_git_hosting(*args, &block)
      repo_path = root_url || url
      full_args = ['git', '--git-dir', repo_path]
      if self.class.client_version_above?([1, 7, 2])
        full_args << '-c' << 'core.quotepath=false'
        full_args << '-c' << 'log.decorate=no'
      end
      full_args += args

      # Compute string from repo_path that should be same as: repo.git_cache_id
      # If only we had access to the repo (we don't).
      OpenProject::GitHosting::GitHosting.logger.debug("Lookup for git_cache_id with repository path '#{repo_path}' ... ")

      git_cache_id = Repository::Git.repo_path_to_git_cache_id(repo_path)

      # if !git_cache_id.nil?
      #   # Insert cache between shell execution and caller
      #   GitHosting.logger.debug("Found git_cache_id ('#{git_cache_id}'), call cache... ")
      #   GitHosting.logger.debug("Send GitCommand : #{full_args.join(" ")}")
      #   Cache.execute(full_args, git_cache_id, options, &block)
      # else
      #   GitHosting.logger.debug { "Unable to find git_cache_id, bypass cache... " }
      OpenProject::GitHosting::GitHosting.logger.debug("Send GitCommand : #{full_args.join(" ")}")
      OpenProject::GitHosting::GitoliteWrapper.sudo_pipe(*full_args, &block)

      #Redmine::Scm::Adapters::AbstractAdapter.shellout(cmd_str, options, &block)
      # end
    end

  end
end

