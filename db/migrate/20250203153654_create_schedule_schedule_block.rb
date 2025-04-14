class CreateScheduleScheduleBlock < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_schedule_schedule_blocks do |t|
      t.integer :dailyschedule_id, :null => false 
      t.integer :block_id, :null => false 
    end 
  end
end
