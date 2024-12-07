class CreateGroupAdvisorsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :group_advisors do |t|
      t.integer :group_id, :null => false
      t.integer :facultystaff_id, :null => false
    end
  end
end
