require_dependency 'redmine/scm/adapters/git_adapter'

module OpenProject::Revisions::Git
  module Patches
    module GitAdapterPatch
      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          alias_method_chain :scm_cmd, :revisions_git
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
          ret = run_scm_cmd(full_args.map { |e| shell_quote e.to_s }.join(' '), &block)
          if $? && $?.exitstatus != 0
            raise ScmCommandAborted, "git exited with non-zero status: #{$?.exitstatus}"
          end
          ret
        end

        def scm_popen_mode
          if RUBY_VERSION < '1.9'
            'r+'
          else
            'r+:ASCII-8BIT'
          end
        end

        def run_scm_cmd(cmd, &block)
          cmd = stderr_if_development(cmd)
          begin
            root = Setting.plugin_openproject_revisions_git[:gitolite_global_storage_path]
            IO.popen(cmd, scm_popen_mode, chdir: root) do |io|
              io.close_write
              block.call(io) if block_given?
            end
          rescue Errno::ENOENT => e
            msg = strip_credential(e.message)
            # The command failed, log it and re-raise
            logger.error("SCM command failed, make sure that your SCM binary (eg. svn)
              is in PATH (#{ENV['PATH']}): #{strip_credential(cmd)}\n  with: #{msg}")
            raise CommandFailed.new(msg)
          end
        end

        # Capture stderr when running in dev environment
        def stderr_if_development(cmd)
          if Rails.env == 'development'
            Rails.logger.debug "Shelling out: #{strip_credential(cmd)}"
            "#{cmd} 2>>#{Rails.root}/log/scm.stderr.log"
          else
            cmd
          end
        end
      end
    end
  end
end
Redmine::Scm::Adapters::GitAdapter.send(:include, OpenProject::Revisions::Git::Patches::GitAdapterPatch)
