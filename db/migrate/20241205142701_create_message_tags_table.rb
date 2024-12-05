class CreateMessageTagsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :message_tags do |t|
      t.string :recipient_tag
    end
  end
end
