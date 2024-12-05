class CreateMessagesTable < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.string :subject, :null => false
      t.text :content, :null => false
      t.datetime :sent_at, :null => false
      t.integer :author_id, :null => false
    end
  end
end
