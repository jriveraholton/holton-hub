class CreateGroupMeetingsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :group_meetings do |t|
      t.string :location, :null => false
      t.datetime :event_date, :null => false
      t.integer :group_id, :null => false
      t.text :description
    end
  end
end
