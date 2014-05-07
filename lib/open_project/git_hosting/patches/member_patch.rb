module OpenProject::GitHosting
  module Patches
    module MemberPatch

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          after_commit  :update_member
        end
      end

      module InstanceMethods

        private

        def update_member
          OpenProject::GitHosting::GitHosting.logger.info("Membership changes on project '#{self.project}', update!")
          OpenProject::GitHosting::GitoliteWrapper.update(:update_members, self.project.id)
        end

      end

    end
  end
end

unless Member.included_modules.include?(OpenProject::GitHosting::Patches::MemberPatch)
  Member.send(:include, OpenProject::GitHosting::Patches::MemberPatch)
end
