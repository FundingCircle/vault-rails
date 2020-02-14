require "binary_serializer"

class EagerPerson < ActiveRecord::Base
  include Vault::EncryptedModel

  self.table_name = "people"

  vault_persist_before_save!

  vault_attribute :ssn

  vault_attribute :credit_card,
    encrypted_column: :cc_encrypted,
    path: "credit-secrets",
    key: "people_credit_cards"

  vault_attribute :details,
    serialize: :json

  vault_attribute :business_card,
    serialize: BinarySerializer

  vault_attribute :favorite_color,
    encode: ->(raw) { "xxx#{raw}xxx" },
    decode: ->(raw) { raw && raw[3...-3] }

  vault_attribute :non_ascii

  vault_attribute :email, convergent: true

  vault_attribute :first_name,
    encrypted_copy: {
      column: 'first_name_custom_encrypted',
      key: -> { "241b3098-656f-4120-bb8d-de5e0640f269" }
    }

  vault_attribute :last_name,
    encrypted_copy: {
      column: 'last_name_custom_encrypted',
      key: -> { "241b3098-656f-4120-bb8d-de5e0640f269" }
    }
end
