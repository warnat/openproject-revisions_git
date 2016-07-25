require 'open3'

module OpenProject::Revisions::Git
  module Utils
    module Exec
      extend self

      # Executes the given command and a list of parameters on the shell
      # and returns the result.
      #
      # If the operation throws an exception or the operation yields a non-zero exit code
      # we rethrow a +GitoliteCommandException+ with a meaningful error message.
      def capture(command, args = [], opts = {}, &block)
        merge_output = opts.delete(:merge_output) { false }
        stdout, stderr, code = execute(command, args, opts, &block)
        if code != 0
          error_msg = "Non-zero exit code #{code} for `#{command} #{args.join(" ")}`"
          OpenProject::Revisions::Git.logger.debug(error_msg)
          raise OpenProject::Revisions::Git::Error::GitoliteCommandException.new(command, error_msg)
        end

        merge_output ? stdout + stderr : stdout
      end


      # Executes the given command and a list of parameters on the shell
      # and returns stdout, stderr, and the exit code.
      #
      # If the operation throws an exception or the operation we rethrow a
      # +GitoliteCommandException+ with a meaningful error message.
      def execute(command, args = [], opts = {}, &block)
        Open3.capture3(command, *args, opts, &block)
      rescue => e
        error_msg = "Exception occured executing `#{command} #{args.join(" ")}` : #{e.message}"
        OpenProject::Revisions::Git.logger.debug(error_msg)
        raise OpenProject::Revisions::Git::Error::GitoliteCommandException.new(command, error_msg)
      end

    end
  end
end
