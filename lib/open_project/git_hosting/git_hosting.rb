require 'open3'

module OpenProject::GitHosting
  module GitHosting

    GITHUB_ISSUE = 'https://github.com/oliverguenther/openproject_git_hosting/issues'
    GITHUB_WIKI  = 'https://github.com/oliverguenther/openproject_git_hosting/wiki/Configuration-variables'

    # Used to register errors when pulling and pushing the conf file
    class GitHostingException < StandardError
      attr_reader :command
      attr_reader :output

      def initialize(command, output)
        @command = command
        @output  = output
      end

      def to_s
        "GitHostingException(#{@command}) -> #{@output}"
      end
    end

    def self.logger
      Rails.logger
    end


    # Returns a rails cache identifier with the key as its last part
    def self.cache_key(key)
      ['/openproject/plugin/git_hosting/', key].join
    end

    # Executes the given command and a list of parameters on the shell
    # and returns the result.
    #
    # If the operation throws an exception or the operation yields a non-zero exit code
    # we rethrow a +GitHostingException+ with a meaningful error message.
    def self.capture(command, *params)
      output, err, code = shell(command, *params)
      if code != 0
        error_msg = "Non-zero exit code #{code} for `#{command} #{params.join(" ")}`"
        logger.error(error_msg)
        raise GitHostingException.new(command, error_msg)
      end

      output
    end


    # Executes the given command and a list of parameters on the shell
    # and returns stdout, stderr, and the exit code.
    #
    # If the operation throws an exception or the operation we rethrow a 
    # +GitHostingException+ with a meaningful error message.
    def self.shell(command, *params)
      Open3.capture3(command, *params)
    rescue => e
      error_msg = "Exception occured executing `#{command} #{params.join(" ")}`: #{e.message}"
      logger.error(error_msg)
      raise GitHostingException.new(command, error_msg)
    end
  end
end
