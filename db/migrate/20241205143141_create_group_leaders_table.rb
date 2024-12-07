class CreateGroupLeadersTable < ActiveRecord::Migration[8.0]
  def change
    create_table :group_leaders do |t|
      t.integer :group_id, :null => false
      t.integer :student_id, :null => false
    end
  end
end
