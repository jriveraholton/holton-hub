class CreateMessageTagsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :message_tags do |t|
      t.string :recipient_tag
      t.boolean :active, :default => true, :null => false
    end
  end
end
