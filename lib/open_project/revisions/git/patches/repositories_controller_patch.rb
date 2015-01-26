module OpenProject::Revisions::Git
  module Patches
    module RepositoriesControllerPatch
      include GitolitePublicKeysHelper

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          alias_method_chain :show, :revisions_git
        end
      end

      module InstanceMethods
        def show_with_revisions_git
          @repository.fetch_changesets if Setting.autofetch_changesets? && @path.blank?

          @entries = @repository.entries(@path, @rev)
          @changeset = @repository.find_changeset_by_name(@rev)
          if request.xhr?
            @entries ? render(partial: 'dir_list_content') : render(nothing: true)
          else
            @changesets = @repository.latest_changesets(@path, @rev)
            @properties = @repository.properties(@path, @rev)
            render action: 'show'
          end
        end
      end
    end
  end
end

RepositoriesController.send(
  :include,
  OpenProject::Revisions::Git::Patches::RepositoriesControllerPatch
)
