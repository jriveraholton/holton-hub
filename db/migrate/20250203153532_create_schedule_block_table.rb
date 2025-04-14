class CreateScheduleBlockTable < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_blocks do |t|
      t.text :description, :null => false
      t.datetime :start, :null => false
      t.integer :duration, :null => false 
    end 
  end
end
