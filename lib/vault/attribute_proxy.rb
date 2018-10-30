
# A simple proxy that aids the transition from
# non-encrypted atributes to encrypted ones.
module Vault
  module AttributeProxy
    extend ActiveSupport::Concern

    module ClassMethods
      # Define proxy getter and setter methods
      #
      # Override the getter and setter for a particular non-encrypted attribute
      # so that they also call the getter/setter of the encrypted one.
      # This ensures that all the code that uses the attribute in question
      # also updates/retrieves the encrypted value whenever it is available.
      #
      # This method is useful if you have a plaintext attribute that you want to replace with a vault attribute.
      # During a transition period both attributes can be seamlessly read/changed at the same time.
      #
      # @param [String | Symbol] non_encrypted_attribute
      #   The name of original attribute (non-encrypted).
      # @param [String | Symbol] encrypted_attribute
      #   The name of the encrypted attribute.
      #   This makes sure that the encrypted attribute behaves like a real AR attribute.
      # @param [Boolean] (false) encrypted_attribute_only
      #   Whether to read and write to both encrypted and non-encrypted attributes.
      #   Useful for when we stop using the non-encrypted one.
      def vault_attribute_proxy(non_encrypted_attribute, encrypted_attribute, options={})
        # Only return the encrypted attribute if it's available and encrypted_attribute_only is true.
        define_method(non_encrypted_attribute) do
          return send(encrypted_attribute) if options[:encrypted_attribute_only]

          send(encrypted_attribute) || super()
        end

        # Update only the encrypted attribute if encrypted_attribute_only is true and both attributes otherwise.
        define_method("#{non_encrypted_attribute}=") do |value|
          super(value) unless options[:encrypted_attribute_only]

          send("#{encrypted_attribute}=", value)
        end
      end
    end
  end
end
