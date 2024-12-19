class CreateGroupLevelsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :group_levels do |t|
      t.string :name, :null => false
      t.text :description, :null => false
      t.integer :limit, :null => false
    end
  end
end
