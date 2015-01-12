require 'gitolite'

module OpenProject::Revisions::Git
  module GitoliteWrapper

    def self.logger
      Rails.logger
    end

    def logger
      self.class.logger
    end

    def self.gitolite_user
      Setting.plugin_openproject_revisions_git[:gitolite_user]
    end

    def self.gitolite_url
      [gitolite_user, '@localhost'].join
    end

    def self.gitolite_version
      logger.debug("Gitolite updating version")
      out, err, code = ssh_shell('info')
      return 3 if out.include?('running gitolite3')
      return 2 if out =~ /gitolite[ -]v?2./
      logger.error("Couldn't retrieve gitolite version through SSH.")
      logger.debug("Gitolite version error output: #{err}") unless err.nil?
      'unknown'
    end

    # Returns a rails cache identifier with the key as its last part
    def self.cache_key(key)
      ['/openproject/revisions/git', key].join
    end

    @@openproject_user = nil
    def self.openproject_user
      @@openproject_user = (%x[whoami]).chomp.strip if @@openproject_user.nil?
      @@openproject_user
    end

    def self.http_server_domain
      Setting.plugin_openproject_revisions_git[:http_server_domain]
    end


    def self.https_server_domain
      Setting.plugin_openproject_revisions_git[:https_server_domain]
    end


    def self.gitolite_server_port
      Setting.plugin_openproject_revisions_git[:gitolite_server_port]
    end

    def self.ssh_server_domain
      Setting.plugin_openproject_revisions_git[:ssh_server_domain]
    end


    def self.gitolite_ssh_private_key
      Setting.plugin_openproject_revisions_git[:gitolite_ssh_private_key]
    end


    def self.gitolite_ssh_public_key
      Setting.plugin_openproject_revisions_git[:gitolite_ssh_public_key]
    end


    def self.git_config_username
      Setting.plugin_openproject_revisions_git[:git_config_username]
    end


    def self.git_config_email
      Setting.plugin_openproject_revisions_git[:git_config_email]
    end

    def self.true?(setting)
      ['true', '1'].include?(Setting.plugin_openproject_revisions_git[setting])
    end

    def self.gitolite_commit_author
      "#{git_config_username} <#{git_config_email}>"
    end

    def self.gitolite_admin_settings
      {
          git_user: gitolite_user,
          host: ssh_server_domain,

          author_name: git_config_username,
          author_email: git_config_email,

          public_key: gitolite_ssh_public_key,
          private_key: gitolite_ssh_private_key,

          key_subdir: 'openproject',
          config_file: 'openproject.conf'
      }
    end



    ##########################
    #                        #
    #   SUDO Shell Wrapper   #
    #                        #
    ##########################


    #
    # Execute a command as the gitolite user defined in +GitoliteWrapper.gitolite_user+.
    #
    # Will shell out to +sudo -n -u <gitolite_user> params+
    #
    def self.sudo_shell(*params)
      OpenProject::Revisions::Shell.capture('sudo', *sudo_shell_params.concat(params))
    end

    #
    # Execute a command as the gitolite user defined in +GitoliteWrapper.gitolite_user+.
    #
    # Instead of capturing the command, it calls the block with the stdout pipe.
    # Raises an exception if the command does not exit with 0.
    #
    def self.sudo_pipe(*params, &block)
      Open3.popen3("sudo", *sudo_shell_params.concat(params))  do |stdin, stdout, stderr, thr|
        begin
          exitcode = thr.value.exitstatus
          if exitcode != 0
            logger.error("sudo call with '#{params.join(" ")}' returned exit #{exitcode}. Error was: #{stderr.read}")
          end
          block.call(stdout)
        ensure
          stdout.close
          stdin.close
        end
      end
    end


    # Return only the output of the shell command
    # Throws an exception if the shell command does not exit with code 0.
    def self.sudo_capture(*params)
      OpenProject::Revisions::Shell.capture_out('sudo', *sudo_shell_params.concat(params))
    end

    # Returns the sudo prefix to all sudo_* commands
    #
    # These are as follows:
    # * (-i) login as `gitolite_user` (setting ENV['HOME')
    # * (-n) non-interactive
    # * (-u `gitolite_user`) target user
    def self.sudo_shell_params
      ['-i', '-n', '-u', gitolite_user]
    end

    # Calls mkdir with the given arguments on the git user's side.
    #
    # e.g., sudo_mkdir('-p', '/some/path)
    #
    def self.sudo_mkdir(*args)
      sudo_capture('mkdir', *args)
    rescue => e
      logger.error("Couldn't move '#{old_path}' => '#{new_path}'. Reason: #{e.message}")
    end

    # Moves a file/directory to a new target.
    # Creates the parent of the target path using mkdir -p.
    #
    def self.sudo_move(old_path, new_path)
      sudo_mkdir('-p', File.dirname(new_path))
      sudo_capture('mv', old_path, new_path)
    rescue => e
      logger.error("Couldn't move '#{old_path}' => '#{new_path}'. Reason: #{e.message}")
    end

    # Removes a directory and all subdirectories below gitolite_user's $HOME.
    #
    # Assumes a relative path.
    #
    # If force=true, it will delete using 'rm -rf <path>', otherwise
    # it uses rmdir
    def self.sudo_rmdir(relative_path, force=false)
      repo_path = File.join('$HOME', relative_path)
      logger.debug("Deleting '#{repo_path}' [forced=#{force ? 'no' : 'yes'}] with git user")

      if force
        sudo_capture('rm','-rf', repo_path)
      else
        sudo_capture('rmdir', repo_path)
      end
    rescue => e
      logger.error("Could not delete repository '#{relative_path}' from disk: #{e.message}")
    end

    # Test if a file or directory exists and is readable to the gitolite user
    # Prepends '$HOME/' to the given path.
    def self.file_exists?(filename)
      sudo_test(filename, '-r')
    end

    # Test if a given path is an empty directory using the git user.
    #
    # Prepends '$HOME/' to the given path.
    def self.sudo_directory_empty?(path)
      home_path = File.join('$HOME', path)
      out, _ , code = GitoliteWrapper.sudo_shell('find', home_path, '-prune', '-empty', '-type', 'd')
      return code == 0 && out.include?(path)
    end

    ##########################
    #                        #
    #       SSH Wrapper      #
    #                        #
    ##########################

    # Execute a command in the gitolite forced environment through this user
    # i.e., executes 'ssh git@localhost <command>'
    #
    # Returns stdout, stderr and the exit code
    def self.ssh_shell(*params)
      OpenProject::Revisions::Shell.capture('ssh', *ssh_shell_params.concat(params))
    end

    # Return only the output from the ssh command and checks
    def self.ssh_capture(*params)
      OpenProject::Revisions::Shell.capture_out('ssh', *ssh_shell_params.concat(params))
    end

    # Returns the ssh prefix arguments for all ssh_* commands
    #
    # These are as follows:
    # * (-T) Never request tty
    # * (-i <gitolite_ssh_private_key>) Use the SSH keys given in Settings
    # * (-p <gitolite_server_port>) Use port from settings
    # * (-o BatchMode=yes) Never ask for a password
    # * <gitolite_user>@localhost (see +gitolite_url+)
    def self.ssh_shell_params
      ['-T', '-o', 'BatchMode=yes', gitolite_url, '-p',
        gitolite_server_port, '-i', gitolite_ssh_private_key]
    end

    ##########################
    #                        #
    #   Gitolite Accessor    #
    #                        #
    ##########################

    def self.admin
      admin_dir = Setting.plugin_openproject_revisions_git[:gitolite_admin_dir]
      logger.info { "Acessing gitolite-admin.git at '#{admin_dir}'" }
      Gitolite::GitoliteAdmin.new(admin_dir, gitolite_admin_settings)
    end

    WRAPPERS = [GitoliteWrapper::Admin, GitoliteWrapper::Repositories,
      GitoliteWrapper::Users, GitoliteWrapper::Projects]

    # Update the Gitolite Repository
    #
    # action: An API action defined in one of the gitolite/* classes.
    def self.update(action, object, options={})
      WRAPPERS.each do |wrappermod|
        if wrappermod.method_defined?(action)
          return wrappermod.new(action,object,options).run
        end
      end

      raise "No available Wrapper for action '#{action}' found."
    end


    ##########################
    #                        #
    #  Config Tests / Setup  #
    #                        #
    ##########################


    # Returns the gitolite welcome/info banner, containing its version.
    #
    # Upon error, returns the shell error code instead.
    def self.gitolite_banner
      GitoliteWrapper.ssh_capture('info')
    rescue => e
      errstr = "Error while getting Gitolite banner: #{e.message}"
      logger.error(errstr)
      errstr
    end

    # Test if the current user can sudo to the gitolite user
    def self.can_sudo_to_gitolite_user?
      test = GitoliteWrapper.sudo_capture('whoami')
      test =~ /#{GitoliteWrapper.gitolite_user}/i
    rescue => e
      logger.error("Exception during sudo config test: #{e.message}")
      false
    end


    # Test properties of a path from the git user.
    # Prepends '$HOME/' to the given path
    #
    # e.g., Test if a directory exists: sudo_test('$HOME/somedir', '-d')
    def self.sudo_test(path, *testarg)
      path = File.join('$HOME', path)
      out, _ , code = GitoliteWrapper.sudo_shell('test', *testarg, path)
      return code == 0
    rescue => e
      logger.debug("File check for #{path} failed: #{e.message}")
      false
    end

  end
end