class CreateDailyScheduleTable < ActiveRecord::Migration[8.0]
  def change
    create_table :dailyschedule do |t|
      t.string :week_type, :null => false 
      t.date :date, :null => false 
      t.string :day_of_the_week, :null => false 
    end 
  end 
end 