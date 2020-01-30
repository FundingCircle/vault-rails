class AddEncryptedCopyColumnsToPerson < ActiveRecord::Migration[5.0]
  def change
    add_column :people, :encryption_metadata, :text

    add_column :people, :first_name_encrypted, :string
    add_column :people, :first_name_custom_encrypted, :string

    add_column :people, :middle_name_encrypted, :string
    add_column :people, :middle_name_custom_encrypted, :string

    add_column :people, :last_name_encrypted, :string
    add_column :people, :last_name_custom_encrypted, :string

    add_column :people, :age_encrypted, :string
    add_column :people, :age_custom_encrypted, :string
  end
end
