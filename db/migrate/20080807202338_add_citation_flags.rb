class AddCitationFlags < ActiveRecord::Migration
  def self.up
    add_column "citations", "rating", :string
  end

  def self.down
    remove_columns "citations", "rating"
  end
end
