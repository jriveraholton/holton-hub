class CreateGroupSeasonsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :group_seasons do |t|
      t.integer :group_id, :null => false
      t.integer :season_id, :null => false
    end
  end
end
