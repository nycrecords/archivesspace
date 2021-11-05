require_relative 'utils'

Sequel.migration do
  up do
    $stderr.puts("Add guid to user table")
    alter_table(:user) do
      add_column(:guid, String)
    end
  end

  down do
    alter_table(:user) do
      drop_column(:guid)
    end
  end
end