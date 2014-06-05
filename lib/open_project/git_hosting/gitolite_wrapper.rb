require 'gitolite'

module OpenProject::GitHosting
  module GitoliteWrapper

    # Used to register errors when pulling and pushing the conf file
    class GitHostingException < StandardError
      attr_reader :command
      attr_reader :output

      def initialize(command, output)
        @command = command
        @output  = output
      end
    end

    def self.logger
      Rails.logger
    end

    def self.gitolite_user
      Setting.plugin_openproject_git_hosting[:gitolite_user]
    end

    def self.gitolite_url
      [gitolite_user, '@localhost'].join
    end

    def self.gitolite_command
      if gitolite_version == 2
        'gl-setup'
      else
        'gitolite setup'
      end
    end

    def self.gitolite_version
      Rails.cache.fetch(GitHosting.cache_key('gitolite_version')) do
        logger.debug("Gitolite updating version")
        out, err, code = ssh_shell('info')
        return 3 if out.include?('running gitolite3')
        return 2 if out =~ /gitolite[ -]v?2./
        logger.error("Couldn't retrieve gitolite version through SSH.")
        logger.debug("Gitolite version error output: #{err}") unless err.nil?
      end
    end

    @@openproject_user = nil
    def self.openproject_user
      @@openproject_user = (%x[whoami]).chomp.strip if @@openproject_user.nil?
      @@openproject_user
    end

    def self.http_server_domain
      Setting.plugin_openproject_git_hosting[:http_server_domain]
    end


    def self.https_server_domain
      Setting.plugin_openproject_git_hosting[:https_server_domain]
    end


    def self.gitolite_server_port
      Setting.plugin_openproject_git_hosting[:gitolite_server_port]
    end

    def self.ssh_server_domain
      Setting.plugin_openproject_git_hosting[:ssh_server_domain]
    end


    def self.gitolite_ssh_private_key
      Setting.plugin_openproject_git_hosting[:gitolite_ssh_private_key]
    end


    def self.gitolite_ssh_public_key
      Setting.plugin_openproject_git_hosting[:gitolite_ssh_public_key]
    end


    def self.git_config_username
      Setting.plugin_openproject_git_hosting[:git_config_username]
    end


    def self.git_config_email
      Setting.plugin_openproject_git_hosting[:git_config_email]
    end

    def self.true?(setting)
      ['true', '1'].include?(Setting.plugin_openproject_git_hosting[setting])
    end

    def self.gitolite_commit_author
      "#{git_config_username} <#{git_config_email}>"
    end

    def self.gitolite_hooks_url
      [Setting.protocol, '://', Setting.host_name, '/githooks/post-receive/redmine'].join
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


    # For SSH'ing to gitolite, use a SSH wraper for use
    # with Git's GIT_SSH command, which only accepts a script name.
    def self.gitolite_admin_ssh_script_path
      File.join(get_scripts_dir_path, "gitolite_admin_ssh")
    end

    def self.get_bin_dir_path
      File.join(File.dirname(__FILE__), '../../../bin/')
    end

    # Return the script dir (defaults to <Plugin Root>/bin).
    def self.get_scripts_dir_path
      scripts_dir = Setting.plugin_openproject_git_hosting[:gitolite_scripts_dir] || bin_dir

      if !File.directory?(scripts_dir)
        logger.info("Create scripts directory : '#{scripts_dir}'")
        FileUtils.mkdir_p scripts_dir
      end

      scripts_dir
    end


    #
    # Execute a command as the gitolite user defined in +GitoliteWrapper.gitolite_user+.
    #
    # Will shell out to +sudo -n -u <gitolite_user> params+
    #
    def self.sudo_shell(*params)
      GitHosting.shell('sudo', *sudo_shell_params.concat(params))
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
          else
            block.call(stdout)
          end
        ensure
          stdout.close
          stdin.close
        end
      end
    end


    # Return only the output of the shell command
    # Throws an exception if the shell command does not exit with code 0.
    def self.sudo_capture(*params)
      GitHosting.capture('sudo', *sudo_shell_params.concat(params))
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

    # Execute a command in the gitolite forced environment through this user
    # i.e., executes 'ssh git@localhost <command>'
    #
    # Returns stdout, stderr and the exit code
    def self.ssh_shell(*params)
      GitHosting.shell('ssh', '-T', gitolite_url, '-p', gitolite_server_port, *params)
    end

    # Return only the output from the ssh command and checks
    def self.ssh_capture(*params)
      GitHosting.capture('ssh', '-T', gitolite_url, '-p', gitolite_server_port, *params)
    end


    ##########################
    #                        #
    #   Gitolite Accessor    #
    #                        #
    ##########################

    def self.admin
      admin_dir = Setting.plugin_openproject_git_hosting[:gitolite_admin_dir]
      logger.info { "Acessing gitolite-admin.git at '#{admin_dir}'" }
      Gitolite::GitoliteAdmin.new(admin_dir, gitolite_admin_settings)
    end

    WRAPPERS = [GitoliteWrapper::Admin, GitoliteWrapper::Repositories, 
      GitoliteWrapper::Users, GitoliteWrapper::Projects]

    # Update the Gitolite Repository
    #
    # action: An API action defined in one of the gitolite/* classes.
    def self.update(action, object, options={})
      if options[:flush_cache] == true
        logger.info("Flushing Settings Cache !")
        Setting.check_cache
      end

      WRAPPERS.each do |wrappermod|
        if wrappermod.method_defined?(action)
          return wrappermod.new(action,object,options).send(action)
        end
      end

      raise GitHostingException.new(action, "No available Wrapper for action '#{action}' found.")
    end

    def purge_recycle_bin
      repositories_array = @object_id
      recycle = Recycle.new
      recycle.delete_expired_files(repositories_array)
      logger.info { "#{@action} : done !" }
    end


    ##########################
    #                        #
    #  Config Tests / Setup  #
    #                        #
    ##########################


    # TODO remove?
    def self.http_root_url
      my_root_url(false)
    end

    # TODO remove?
    def self.https_root_url
      my_root_url(true)
    end

    # TODO remove?
    def self.my_root_url(ssl = false)
      # Remove any path from httpServer in case they are leftover from previous installations.
      # No trailing /.
      my_root_path = OpenProject::Configuration.rails_relative_url_root

      if ssl && https_server_domain != ''
        server_domain = https_server_domain
      else
        server_domain = http_server_domain
      end

      my_root_url = File.join(server_domain[/^[^\/]*/], my_root_path, "/")[0..-2]

      return my_root_url
    end

    # Returns the gitolite welcome/info banner, containing its version.
    # 
    # Upon error, returns the shell error code instead.
    def self.gitolite_banner
      Rails.cache.fetch(GitHosting.cache_key('gitolite_banner')) {
        logger.debug("Retrieving gitolite banner")
        begin
          GitoliteWrapper.ssh_capture('info')
        rescue => e
          errstr = "Error while getting Gitolite banner: #{e.message}"
          logger.error(errstr)
          errstr
        end
      }
    end

    # Test if the current user can sudo to the gitolite user
    def self.can_sudo_to_gitolite_user?
      Rails.cache.fetch(GitHosting.cache_key('test_gitolite_sudo')) {
        begin
          test = GitoliteWrapper.sudo_capture('whoami')
          test =~ /#{GitoliteWrapper.gitolite_user}/i
        rescue => e
          logger.error("Exception during sudo config test: #{e.message}")
          false
        end
      }
    end

    ## Test if a file exists and is readable to the gitolite user
    def self.file_exists?(filename)
      begin
        out, err, code = GitoliteWrapper.sudo_shell('test', '-r', filename)
        return code == 0
      rescue => e
        logger.error("File check for #{filename} failed: #{e.message}")
        false
      end
    end

    def self.gitolite_admin_ssh_script_is_installed?
      Rails.cache.fetch(GitHosting.cache_key('admin_ssh_script_installed?')) do
        if File.exists?(gitolite_admin_ssh_script_path)
          true
        else
          setup_admin_ssh_script
        end
      end
    end

    def self.setup_admin_ssh_script
      logger.info("Create script file : '#{gitolite_admin_ssh_script_path}'")
      File.open(gitolite_admin_ssh_script_path, "w") do |f|
        f.puts "#!/bin/sh"
        f.puts "exec ssh -T -o BatchMode=yes -o StrictHostKeyChecking=no -p #{gitolite_server_port} -i #{gitolite_ssh_private_key} \"$@\""
      end

      File.chmod(0550, gitolite_admin_ssh_script_path) > 0
    rescue => e
      logger.error("Cannot create script file '#{gitolite_admin_ssh_script_path}': #{e.message}")
      false
    end


    ###############################
    ##                           ##
    ##      MIRRORING KEYS       ##
    ##                           ##
    ###############################

    GITOLITE_DEFAULT_CONFIG_FILE       = 'gitolite.conf'
    GITOLITE_IDENTIFIER_DEFAULT_PREFIX = 'redmine_'

    GITOLITE_MIRRORING_KEYS_NAME   = "redmine_gitolite_admin_id_rsa_mirroring"
    GITOLITE_SSH_PRIVATE_KEY_PATH  = "~/.ssh/#{GITOLITE_MIRRORING_KEYS_NAME}"
    GITOLITE_SSH_PUBLIC_KEY_PATH   = "~/.ssh/#{GITOLITE_MIRRORING_KEYS_NAME}.pub"
    GITOLITE_MIRRORING_SCRIPT_PATH = '~/.ssh/run_gitolite_admin_ssh'

    @@mirroring_public_key = nil

    def self.mirroring_public_key
      if @@mirroring_public_key.nil?
        public_key = (%x[ cat '#{gitolite_ssh_public_key}' ]).chomp.strip
        @@mirroring_public_key = public_key.split(/[\t ]+/)[0].to_s + " " + public_key.split(/[\t ]+/)[1].to_s
      end

      return @@mirroring_public_key
    end


    @@mirroring_keys_installed = false

    def self.mirroring_keys_installed?(opts = {})
      @@mirroring_keys_installed = false if opts.has_key?(:reset) && opts[:reset] == true

      if !@@mirroring_keys_installed
        logger.info { "Installing Redmine Gitolite mirroring SSH keys ..." }

        begin
          # GitHosting.execute_command(:shell_cmd, "'cat > #{GITOLITE_SSH_PRIVATE_KEY_PATH}'", :pipe_data => "'#{gitolite_ssh_private_key}'", :pipe_command => 'cat')
          # GitHosting.execute_command(:shell_cmd, "'cat > #{GITOLITE_SSH_PUBLIC_KEY_PATH}'",  :pipe_data => "'#{gitolite_ssh_public_key}'",  :pipe_command => 'cat')

          # GitHosting.execute_command(:shell_cmd, "'chmod 600 #{GITOLITE_SSH_PRIVATE_KEY_PATH}'")
          # GitHosting.execute_command(:shell_cmd, "'chmod 644 #{GITOLITE_SSH_PUBLIC_KEY_PATH}'")

          # git_user_dir = GitHosting.execute_command(:shell_cmd, "'cd ~ && pwd'").chomp.strip

          # command = 'exec ssh -T -o BatchMode=yes -o StrictHostKeyChecking=no -i ' + "#{git_user_dir}/.ssh/#{GITOLITE_MIRRORING_KEYS_NAME}" + ' "$@"'

          # GitHosting.execute_command(:shell_cmd, "'cat > #{GITOLITE_MIRRORING_SCRIPT_PATH}'",  :pipe_data => "#!/bin/sh", :pipe_command => 'echo')
          # GitHosting.execute_command(:shell_cmd, "'cat >> #{GITOLITE_MIRRORING_SCRIPT_PATH}'", :pipe_data => command, :pipe_command => 'echo')

          # GitHosting.execute_command(:shell_cmd, "'chmod 700 #{GITOLITE_MIRRORING_SCRIPT_PATH}'")

          logger.info { "Done !" }

          @@mirroring_keys_installed = true
        rescue GitHosting::GitHostingException => e
          logger.error { "Failed installing Redmine Gitolite mirroring SSH keys !" }
          logger.error { e.output }
          @@mirroring_keys_installed = false
        end
      end

      return @@mirroring_keys_installed
    end    
  end
end