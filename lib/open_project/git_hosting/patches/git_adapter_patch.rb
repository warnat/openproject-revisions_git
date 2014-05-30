require_dependency 'redmine/scm/adapters/git_adapter'

module OpenProject::GitHosting::Patches::GitAdapterPatch
  def self.included(base)
    base.class_eval do
      unloadable

      include InstanceMethods
      extend ClassMethods

      class << self
        alias_method_chain :sq_bin,         :git_hosting
        alias_method_chain :client_command, :git_hosting
      end

      alias_method_chain :scm_cmd, :git_hosting
    end
  end


  module ClassMethods

    def sq_bin_with_git_hosting
      return Redmine::Scm::Adapters::GitAdapter::shell_quote(Config.git_cmd_runner)
    end

    def client_command_with_git_hosting
      return Config.git_cmd_runner
    end

  end


  module InstanceMethods

    private

    def scm_cmd_with_git_hosting(args, options = {}, &block)
      repo_path = root_url || url
      full_args = [Config.git_cmd_runner, '--git-dir', repo_path]
      if self.class.client_version_above?([1, 7, 2])
        full_args << '-c' << 'core.quotepath=false'
        full_args << '-c' << 'log.decorate=no'
      end
      full_args += args

      cmd_str = full_args.map { |e| shell_quote e.to_s }.join(' ')

      # Compute string from repo_path that should be same as: repo.git_cache_id
      # If only we had access to the repo (we don't).
      GitHosting.logger.debug { "Lookup for git_cache_id with repository path '#{repo_path}' ... " }

      git_cache_id = Repository::Git.repo_path_to_git_cache_id(repo_path)

      if !git_cache_id.nil?
        # Insert cache between shell execution and caller
        GitHosting.logger.debug { "Found git_cache_id ('#{git_cache_id}'), call cache... " }
        GitHosting.logger.debug { "Send GitCommand : #{cmd_str}" }
        Cache.execute(cmd_str, git_cache_id, options, &block)
      else
        GitHosting.logger.debug { "Unable to find git_cache_id, bypass cache... " }
        GitHosting.logger.debug { "Send GitCommand : #{cmd_str}" }
        Redmine::Scm::Adapters::AbstractAdapter.shellout(cmd_str, options, &block)
      end
    end

  end
end

