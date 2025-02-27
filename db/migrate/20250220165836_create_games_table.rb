class CreateGamesTable < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.text :name, :null => false
      t.integer :team_id, :null => false
      t.datetime :date, :null => false
      t.boolean :advantage
      t.integer :home_score
      t.integer :away_score
      t.text :details
      t.string :result
      t.boolean :status, :null => false, :default => true
    end
  end
end
