class CreateBwEventDivisionsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :bw_event_divisions do |t|
      t.integer :bw_event_id, :null => false
      t.integer :division_id, :null => false
    end
  end
end
