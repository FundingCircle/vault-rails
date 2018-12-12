require "binary_serializer"

class Person < ActiveRecord::Base
  include Vault::EncryptedModel
  include Vault::AttributeProxy

  vault_attribute :date_of_birth_plaintext
  vault_attribute_proxy :date_of_birth, :date_of_birth_plaintext, type: :date

  vault_attribute :county_plaintext, encrypted_column: :county_encrypted
  vault_attribute_proxy :county, :county_plaintext

  vault_attribute :state_plaintext, encrypted_column: :state_encrypted
  vault_attribute_proxy :state, :state_plaintext, encrypted_attribute_only: true

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

  vault_attribute :driving_licence_number, convergent: true
  validates :driving_licence_number, vault_uniqueness: true, allow_nil: true

  vault_attribute :ip_address, convergent: true, serialize: :ipaddr
  validates :ip_address, vault_uniqueness: true, allow_nil: true
end

