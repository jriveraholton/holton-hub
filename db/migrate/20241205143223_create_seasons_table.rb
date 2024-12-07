class CreateSeasonsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :seasons do |t|
      t.string :name, :null => false
      t.datetime :start_date, :null => false
    end
  end
end
