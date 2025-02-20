class CreateFacultystaffTable < ActiveRecord::Migration[8.0]
  def change
    create_table :facultystaffs do |t|
      t.integer :grade
      t.integer :user_id
    end
  end
end
