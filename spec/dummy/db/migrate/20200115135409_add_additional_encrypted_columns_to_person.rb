class AddAdditionalEncryptedColumnsToPerson < ActiveRecord::Migration[5.2]
  def change
    add_column :people, :first_name_encrypted, :string
    add_column :people, :first_name_custom_encrypted, :string
    add_column :people, :encryption_key, :string
  end
end
