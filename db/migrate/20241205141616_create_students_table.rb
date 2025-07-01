class CreateStudentsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :students do |t|
      t.integer :class_of, :null => false
      t.integer :user_id, :null => false
      t.boolean :active, :default => true, :null => false
    end
  end
end
