class CreateUsersTable < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :firstname, :null => false
      t.string :lastname, :null => false
      t.string :email, :null => false
      t.string :secret
      t.integer :team_id#, :null => false
      t.boolean :is_admin, :null => false, :default => false
    end
  end
end
