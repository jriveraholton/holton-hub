
class CreateGroupsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name, :null => false
      t.text :description, :null => false
      t.string :group_type, :null => false
      t.integer :level_id, :null => false
      t.boolean :active, :null => false, :default => true
    end
  end
end
