require_dependency 'redmine/scm/adapters/git_adapter'

module OpenProject::Revisions::Git
  module Patches
    module GitAdapterPatch
      
      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods
          extend ClassMethods

          class << self
            alias_method_chain :scm_version_from_command_line, :revisions_git
          end

          alias_method_chain :scm_cmd, :revisions_git
        end
      end


      module ClassMethods

        def scm_version_from_command_line_with_revisions_git
          OpenProject::Revisions::Git::GitoliteWrapper.sudo_capture('git', '--version', '--no-color')
        rescue => e
           OpenProject::Revisions::Git::GitoliteWrapper.logger.error("Can't retrieve git version: #{e}")
          'unknown'
        end

      end


      module InstanceMethods

        private

        def scm_cmd_with_revisions_git(*args, &block)
          repo_path = root_url || url
          full_args = ['git', '--git-dir', repo_path]
          if self.class.client_version_above?([1, 7, 2])
            full_args << '-c' << 'core.quotepath=false'
            full_args << '-c' << 'log.decorate=no'
          end
          full_args += args

          OpenProject::Revisions::Git::GitoliteWrapper.logger.debug("Send GitCommand : #{full_args.join(" ")}")
          OpenProject::Revisions::Git::GitoliteWrapper.sudo_pipe(*full_args, &block)
        end

      end
    end
  end
end
Redmine::Scm::Adapters::GitAdapter.send(:include, OpenProject::Revisions::Git::Patches::GitAdapterPatch)

