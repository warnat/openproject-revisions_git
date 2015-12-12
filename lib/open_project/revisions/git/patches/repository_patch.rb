module OpenProject::Revisions::Git
  module Patches
    module RepositoryPatch
      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          has_many :repository_deployment_credentials, dependent: :destroy
          has_many :repository_post_receive_urls, dependent: :destroy
          has_many :repository_mirrors, dependent: :destroy

        end
      end

      module InstanceMethods


        protected


        private


      end
    end
  end
end

Repository.send(:include, OpenProject::Revisions::Git::Patches::RepositoryPatch)
