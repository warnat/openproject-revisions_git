module OpenProject::Revisions::Git
  module Commands
    module Base
      extend self

      # Wrapper to Open3.capture.
      #
      def capture(args = [], opts = {})
        cmd = args.shift
        OpenProject::Revisions::Git::Utils::Exec.capture(cmd, args, opts)
      end


      # Wrapper to Open3.capture.
      #
      def execute(args = [], opts = {})
        cmd = args.shift
        OpenProject::Revisions::Git::Utils::Exec.execute(cmd, args, opts)
      end


      private


        def logger
          OpenProject::Revisions::Git.logger
        end

    end
  end
end
