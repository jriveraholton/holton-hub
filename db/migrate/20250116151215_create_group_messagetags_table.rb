class CreateGroupMessagetagsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :group_messagetags do |t|
      t.integer :group_id, :null => false
      t.integer :messagetag_id, :null => false
    end
  end
end
