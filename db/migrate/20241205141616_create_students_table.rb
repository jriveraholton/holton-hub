class CreateStudentsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :students do |t|
      t.integer :grade, :null => false
      t.integer :user_id, :null => false
    end
  end
end
