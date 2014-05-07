module OpenProject::GitHosting
  module Patches
    module RepositoriesHelperPatch

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          alias_method_chain :git_field_tags, :git_hosting
        end
      end

      module InstanceMethods

        # Add a public_keys tab to the user administration page
        def git_field_tags_with_git_hosting(form,repository)
          content_tag('p', form.text_field(:url, :label => :label_git_path, :size => 60, :required => true, :disabled => (repository && !repository.root_url.blank?)))
        end
      end
    end
  end
end

unless RepositoriesHelper.included_modules.include?(OpenProject::GitHosting::Patches::RepositoriesHelperPatch)
  RepositoriesHelper.send(:include, OpenProject::GitHosting::Patches::RepositoriesHelperPatch)
end
