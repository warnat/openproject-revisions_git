module RepositoryDeploymentCredentialsHelper

  def build_list_of_keys(user_deployment_keys)
    option_array = [['Select a deployment key', -1]]
    option_array += user_deployment_keys.map { |key| [keylabel_text(key), key.id] }


    options_for_select(option_array, selected: -1)
  end

end
