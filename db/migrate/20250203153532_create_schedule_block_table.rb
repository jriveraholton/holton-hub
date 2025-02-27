class CreateScheduleBlockTable < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_block do |t|
      t.string :name, :null => false 
      t.text :description 
      t.datetime :start_time, :null => false
      t.string :duration, :null => false 
    end 
  end
end
