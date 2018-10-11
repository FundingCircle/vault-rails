require "spec_helper"

describe Vault::EncryptedModel do
  describe ".vault_attribute" do
    let(:person) { Person.new }

    it "raises an exception if a serializer and :encode is given" do
      expect {
        Person.vault_attribute(:foo, serializer: :json, encode: ->(r) { r })
      }.to raise_error(Vault::Rails::ValidationFailedError)
    end

    it "raises an exception if a serializer and :decode is given" do
      expect {
        Person.vault_attribute(:foo, serializer: :json, decode: ->(r) { r })
      }.to raise_error(Vault::Rails::ValidationFailedError)
    end

    it "defines a getter" do
      expect(person).to respond_to(:ssn)
    end

    it "defines a setter" do
      expect(person).to respond_to(:ssn=)
    end

    it "defines a checker" do
      expect(person).to respond_to(:ssn?)
    end

    it "defines dirty attribute methods" do
      expect(person).to respond_to(:ssn_change)
      expect(person).to respond_to(:ssn_changed?)
      expect(person).to respond_to(:ssn_was)
    end
  end
end
