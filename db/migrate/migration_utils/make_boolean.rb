module MakeBoolean

  # Postgres for one doesn't allow an integer column to be changed
  # directly to a boolean without USING CAST(..).
  # This helper transform a column to boolean using a temporary column
  # without resorting to raw SQL
  def change_column_to_boolean(model, column_name, default=false)
    tmp_column = "#{column_name}_tmp"
    add_column model.table_name, tmp_column, :boolean, :default => default

    # Populate temp column
    model.reset_column_information # make the new column available to model methods
    model.where(column_name => 1).update_all(tmp_column => true) 

    remove_column model.table_name, column_name
    rename_column model.table_name, tmp_column, column_name
  end

end