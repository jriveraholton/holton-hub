class CreateMessageMessageTagsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :message_message_tags do |t|
      t.integer :message_id, :null => false
      t.integer :message_tag_id, :null => false
    end
  end
end
