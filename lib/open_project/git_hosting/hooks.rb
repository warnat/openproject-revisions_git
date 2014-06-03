require 'digest/md5'
require 'byebug'

module OpenProject::GitHosting

  class AttributeHook < Redmine::Hook::ViewListener
    render_on :view_create_project_form_attributes, :partial => 'projects/form/attributes/git_project'
  end

  class GitoliteHook < Redmine::Hook::Listener

    GITOLITE_HOOKS_DIR       = '~/.gitolite/hooks/common'
    GITOLITE_HOOKS_NAMESPACE = 'OpenProjectGitHosting'

    POST_RECEIVE_HOOK_DIR    = File.join(GITOLITE_HOOKS_DIR, 'post-receive.d')
    PACKAGE_HOOKS_DIR        = File.join(File.dirname(File.dirname(File.dirname(__FILE__))), 'contrib', 'hooks')

    POST_RECEIVE_HOOKS    = {
      'post-receive.redmine_gitolite.rb'   => { :source => 'post-receive.redmine_gitolite.rb',   :destination => 'post-receive',                      :executable => true },
    }


    attr_accessor :gitolite_hooks_url
    attr_accessor :gitolite_hooks_namespace


    def initialize
      @gitolite_command   = OpenProject::GitHosting::GitoliteWrapper.gitolite_command
      @gitolite_hooks_url = OpenProject::GitHosting::GitoliteWrapper.gitolite_hooks_url
      @debug_mode         = OpenProject::GitHosting::GitoliteWrapper.true?(:gitolite_hooks_debug)
      @async_mode         = OpenProject::GitHosting::GitoliteWrapper.true?(:gitolite_hooks_are_asynchronous)
      @force_hooks_update = OpenProject::GitHosting::GitoliteWrapper.true?(:gitolite_force_hooks_update)

      @global_hook_params = get_global_hooks_params
      @gitolite_hooks_namespace = GITOLITE_HOOKS_NAMESPACE
    end

    def self.logger
      Rails.logger
    end

    def logger
      self.class.logger
    end

    def check_install
      return [ hooks_installed?, hook_params_installed? ]
    end


    def hooks_installed?
      installed = {}

      installed['post-receive.d'] = check_hook_dir_installed

      POST_RECEIVE_HOOKS.each do |hook|
        installed[hook[0]] = check_hook_file_installed(hook)
      end

      return installed
    end


    def hook_params_installed?
      installed = {}

      if @global_hook_params["redmineurl"] != @gitolite_hooks_url
        installed['redmineurl'] = set_hook_param("redmineurl", @gitolite_hooks_url)
      else
        installed['redmineurl'] = true
      end

      if @global_hook_params["debugmode"] != @debug_mode.to_s
        installed['debugmode'] = set_hook_param("debugmode", @debug_mode.to_s)
      else
        installed['debugmode'] = true
      end

      if @global_hook_params["asyncmode"] != @async_mode.to_s
        installed['asyncmode'] = set_hook_param("asyncmode", @async_mode.to_s)
      else
        installed['asyncmode'] = true
      end

      return installed
    end


    private


    ###############################
    ##                           ##
    ##         HOOKS DIR         ##
    ##                           ##
    ###############################


    @@check_hooks_dir_installed_cached = nil
    @@check_hooks_dir_installed_stamp = nil


    def check_hook_dir_installed
      if !@@check_hooks_dir_installed_cached.nil? && (Time.new - @@check_hooks_dir_installed_stamp <= 1)
        return @@check_hooks_dir_installed_cached
      end

      hook_dir_exists = GitoliteWrapper.file_exists?(POST_RECEIVE_HOOK_DIR)

      if !hook_dir_exists
        logger.info { "Global hook directory '#{POST_RECEIVE_HOOK_DIR}' not created yet, installing it..." }

        if install_hooks_dir(POST_RECEIVE_HOOK_DIR)
          logger.info { "Global hook directory '#{POST_RECEIVE_HOOK_DIR}' installed" }
          @@check_hooks_dir_installed_cached = true
        else
          @@check_hooks_dir_installed_cached = false
        end

        @@check_hooks_dir_installed_stamp = Time.new
      else
        logger.info { "Global hook directory '#{POST_RECEIVE_HOOK_DIR}' is already present, will not touch it !" }
        @@check_hooks_dir_installed_cached = true
        @@check_hooks_dir_installed_stamp = Time.new
      end

      return @@check_hooks_dir_installed_cached
    end


    def install_hooks_dir(hook_dir)
      logger.info { "Installing hook directory '#{hook_dir}'" }
      GitoliteWrapper.sudo_shell('mkdir', '-p', hook_dir)
      GitoliteWrapper.sudo_shell('chmod', '755', hook_dir)
      true
    rescue => e
      logger.error { "Problems installing hook directory '#{hook_dir}': #{e.message}" }
      false
    end


    ###############################
    ##                           ##
    ##         HOOK FILES        ##
    ##                           ##
    ###############################


    @@check_hooks_installed_stamp = {}
    @@check_hooks_installed_cached = {}
    @@post_receive_hook_path = {}


    def check_hook_file_installed(hook)

      hook_name = hook[0]
      hook_data = hook[1]

      if !@@check_hooks_installed_cached[hook_name].nil? && (Time.new - @@check_hooks_installed_stamp[hook_name] <= 1)

        if hook_digest(hook_data) == digest
          logger.info { "Our '#{hook_name}' hook is already installed" }
          @@check_hooks_installed_stamp[hook_name] = Time.new
          @@check_hooks_installed_cached[hook_name] = true
          return @@check_hooks_installed_cached[hook_name]

        else

          error_msg = "Hook '#{hook_name}' is already present but it's not ours!"
          logger.warn { error_msg }
          @@check_hooks_installed_cached[hook_name] = error_msg

          if @force_hooks_update
            logger.info { "Restoring '#{hook_name}' hook since forceInstallHook == true" }

            if install_hook_file(hook_data)
              logger.info { "Hook '#{hook_name}' installed" }
              logger.info { "Running '#{@gitolite_command}' on the Gitolite install..." }

              if update_gitolite
                @@check_hooks_installed_cached[hook_name] = true
              else
                @@check_hooks_installed_cached[hook_name] = false
              end
            else
              @@check_hooks_installed_cached[hook_name] = false
            end
          end

          @@check_hooks_installed_stamp[hook_name] = Time.new
          return @@check_hooks_installed_cached[hook_name]
        end

      end
    end


    def install_hook_file(hook_data)
      source_path      = File.join(PACKAGE_HOOKS_DIR, hook_data[:source])
      destination_path = File.join(GITOLITE_HOOKS_DIR, hook_data[:destination])

      if hook_data[:executable]
        filemode = 755
      else
        filemode = 644
      end

      logger.info { "Installing hook '#{source_path}' in '#{destination_path}'" }

      begin
        pipe_target = GitoliteWrapper.sudo_shell_params.concat(['tee', '-a', destination_path])
        Open3.pipeline(['cat', source_path], pipe_target) do |procs|
          raise "Hook was not copied." unless GitoliteWrapper.file_exists?(destination_path)
          
          GitoliteWrapper.sudo_shell("chmod", filemode, destination_path)
          return true
        end
      rescue => e
        logger.error { "Problems installing hook from '#{source_path}' in '#{destination_path}': #{e.message}" }
        return false
      end
    end


    def hook_digest(hook_data)
      hook_name   = hook_data[:source]
      source_path = File.join(PACKAGE_HOOKS_DIR, hook_data[:source])

      digest = Digest::MD5.hexdigest(File.read(source_path))
      logger.debug "Digest for '#{hook_name}' hook : #{digest}"

      return digest
    end


    def update_gitolite
      begin
        GitoliteWrapper.sudo_capture(@gitolite_command)
        return true
      rescue GitHosting::GitHostingException => e
        return false
      end
    end


    # Return a hash with global config parameters.
    def get_global_hooks_params
      begin
        # TODO get-regexp -> get-all?
        hooks_params = GitoliteWrapper.sudo_capture("git", "config", "--global", "--get-regexp", GITOLITE_HOOKS_NAMESPACE).split("\n")
      rescue => e
        logger.error { "Problems to retrieve Gitolite hook parameters in Gitolite config" }
        hooks_params = []
      end

      value_hash = {}

      hooks_params.each do |value_pair|
        global_key = value_pair.split(' ')[0]
        namespace  = global_key.split('.')[0]
        key        = global_key.split('.')[1]
        value      = value_pair.split(' ')[1]

        if namespace == GITOLITE_HOOKS_NAMESPACE
          value_hash[key] = value
        end
      end

      return value_hash
    end

    # Returns the global gitconfig prefix for
    # a config with that given key under the
    # hooks namespace.
    #
    def gitconfig_prefix(key)
      [GITOLITE_HOOKS_NAMESPACE, '.', key].join
    end


    def set_hook_param(name, value)
      logger.info { "Set Git hooks global parameter : #{name} (#{value})" }

      begin
        GitoliteWrapper.sudo_capture("git", "config", "--global", gitconfig_prefix(name), value)
        return true
      rescue GitHosting::GitHostingException => e
        logger.error { "Error while setting Git hooks global parameter : #{name} (#{value})" }
        return false
      end

    end

  end
end
