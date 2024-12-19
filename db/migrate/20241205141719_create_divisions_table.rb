class CreateDivisionsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :divisions do |t|
      t.string :name, :null => false
    end
  end
end
