module OpenProject::GitHosting
  module Patches
    module RepositoriesHelperPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          alias_method_chain :git_field_tags, :git_hosting
        end
      end

      module InstanceMethods

        # Add a public_keys tab to the user administration page
        def git_field_tags_with_git_hosting(form,repository)
          render :partial => 'projects/settings/git', :locals => { :form => form, :repository => repository }
        end
      end
    end
  end
end

RepositoriesHelper.send(:include, OpenProject::GitHosting::Patches::RepositoriesHelperPatch)
