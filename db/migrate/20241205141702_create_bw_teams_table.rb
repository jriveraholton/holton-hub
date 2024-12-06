class CreateBwTeamsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :bw_teams do |t|
      t.string :team_color, :null => false
      t.integer :captain_id, :null => false
      t.integer :win_count, :null => false, :default => 0
    end
  end
end
