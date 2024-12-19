class CreateBwEventsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :bw_events do |t|
      t.string :name, :null => false
      t.datetime :event_date, :null => false
      t.integer :blue_points
      t.integer :white_points
      t.integer :division_id, :null => false
    end
  end
end
