class CreateGroupMembersTable < ActiveRecord::Migration[8.0]
  def change
    create_table :group_members do |t|
      t.integer :student_id, :null => false
      t.integer :group_id, :null => false
    end
  end
end
