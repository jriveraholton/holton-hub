class CreateUserMessagesTable < ActiveRecord::Migration[8.0]
  def change
    create_table :user_messages do |t|
      t.integer :user_id, :null => false
      t.integer :message_id, :null => false
      t.boolean :unread, default: true, :null => false
    end
  end
end
