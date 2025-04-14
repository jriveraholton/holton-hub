class CreateDailyScheduleTable < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_schedules do |t|
      t.string :week_type, :null => false 
      t.integer :day, :null => false 
      t.string :day_of_the_week, :null => false 
      t.datetime :date_of, :null => false
    end 
  end 
end 