require "active_support/concern"

module Vault
  module EncryptedModel
    extend ActiveSupport::Concern

    module ClassMethods
      # Creates an attribute that is read and written using Vault.
      #
      # @example
      #
      #   class Person < ActiveRecord::Base
      #     include Vault::EncryptedModel
      #     vault_attribute :ssn
      #   end
      #
      #   person = Person.new
      #   person.ssn = "123-45-6789"
      #   person.save
      #   person.encrypted_ssn #=> "vault:v0:6hdPkhvyL6..."
      #
      # @param [Symbol] column
      #   the column that is encrypted
      # @param [Hash] options
      #
      # @option options [Symbol] :encrypted_column
      #   the name of the encrypted column (default: +#{column}_encrypted+)
      # @option options [Bool] :convergent
      #   use convergent encryption (default: +false+)
      # @option options [String] :path
      #   the path to the transit backend (default: +transit+)
      # @option options [String] :key
      #   the name of the encryption key (default: +#{app}_#{table}_#{column}+)
      # @option options [Symbol, Class] :serializer
      #   the name of the serializer to use (or a class)
      # @option options [Proc] :encode
      #   a proc to encode the value with
      # @option options [Proc] :decode
      #   a proc to decode the value with
      def vault_attribute(attribute_name, options = {})
        encrypted_column = options[:encrypted_column] || "#{attribute_name}_encrypted"
        path = options[:path] || "transit"
        key = options[:key] || "#{Vault::Rails.application}_#{table_name}_#{attribute_name}"
        convergent = options.fetch(:convergent, false)

        # Sanity check options!
        _vault_validate_options!(options)

        # Get the serializer if one was given.
        serializer = options[:serialize]

        # Unless a class or module was given, construct our serializer. (Slass
        # is a subset of Module).
        if serializer && !serializer.is_a?(Module)
          serializer = Vault::Rails.serializer_for(serializer)
        end

        # See if custom encoding or decoding options were given.
        if options[:encode] && options[:decode]
          serializer = Class.new
          serializer.define_singleton_method(:encode, &options[:encode])
          serializer.define_singleton_method(:decode, &options[:decode])
        end

        attribute_type = options.fetch(:type, :value)

        if attribute_type.is_a?(Symbol)
          attribute_type = attribute_type.to_s.camelize
          attribute_type = ActiveRecord::Type.const_get(attribute_type).new
        end

        # Attribute API
        attribute(attribute_name, attribute_type)

        # Getter
        define_method(attribute_name) do
          read_attribute(attribute_name) || __vault_load_attribute!(attribute_name, self.class.__vault_attributes[attribute_name])
        end

        # Setter
        define_method("#{attribute_name}=") do |value|
          # Force the update of the attribute, to be sonsistent with old behaviour
          attribute_will_change!(attribute_name)
          write_attribute(attribute_name, value)
        end


        # Make a note of this attribute so we can use it in the future (maybe).
        __vault_attributes[attribute_name.to_sym] = {
          key: key,
          path: path,
          serializer: serializer,
          encrypted_column: encrypted_column,
          convergent: convergent
        }

        self
      end

      # The list of Vault attributes.
      #
      # @return [Hash]
      def __vault_attributes
        @vault_attributes ||= {}
      end

      # Validate that Vault options are all a-okay! This method will raise
      # exceptions if something does not make sense.
      def _vault_validate_options!(options)
        if options[:serializer]
          if options[:encode] || options[:decode]
            raise Vault::Rails::ValidationFailedError, "Cannot use a " \
              "custom encoder/decoder if a `:serializer' is specified!"
          end
        end

        if options[:encode] && !options[:decode]
          raise Vault::Rails::ValidationFailedError, "Cannot specify " \
            "`:encode' without specifying `:decode' as well!"
        end

        if options[:decode] && !options[:encode]
          raise Vault::Rails::ValidationFailedError, "Cannot specify " \
            "`:decode' without specifying `:encode' as well!"
        end
      end

      def vault_lazy_decrypt?
        !!@vault_lazy_decrypt
      end

      def vault_lazy_decrypt!
        @vault_lazy_decrypt = true
      end
    end

    included do
      # After a resource has been initialized, immediately communicate with
      # Vault and decrypt any attributes unless vault_lazy_decrypt is set.
      after_initialize :__vault_load_attributes!

      # The reason we use `before_save` here is to avoid multiple queries
      # to the database. Also, Rails 5.2 changes the behaviour of dirty
      # attribures and makes it difficult to track changes in virtual attributes.
      before_save :__vault_encrypt_attributes!

      # Decrypt all the attributes from Vault.
      def __vault_load_attributes!
        return if self.class.vault_lazy_decrypt?

        self.class.__vault_attributes.each do |attribute, options|
          self.__vault_load_attribute!(attribute, options)
        end
      end

      # Decrypt and load a single attribute from Vault.
      def __vault_load_attribute!(attribute, options)
        # If the user provided a value for the attribute, do not try to load it from Vault
        return if attribute_changed?(attribute)

        key        = options[:key]
        path       = options[:path]
        serializer = options[:serializer]
        column     = options[:encrypted_column]
        convergent = options[:convergent]

        # Load the ciphertext
        ciphertext = read_attribute(column)

        # Load the plaintext value
        plaintext = Vault::Rails.decrypt(path, key, ciphertext, Vault.client, convergent)

        # Deserialize the plaintext value, if a serializer exists
        plaintext = serializer.decode(plaintext) if serializer

        # Write the virtual attribute with the plaintext value
        write_attribute(attribute, plaintext)
      end

      def __vault_encrypt_attributes!
        self.class.__vault_attributes.each do |attribute, options|
          # Only persist changed attributes to minimize requests - this helps
          # minimize the number of requests to Vault.
          next unless attribute_changed?(attribute)

          self.__vault_encrypt_attribute!(attribute, options)
        end
      end

      # Encrypt a single attribute using Vault and persist back onto the
      # encrypted attribute value.
      def __vault_encrypt_attribute!(attribute, options)
        key        = options[:key]
        path       = options[:path]
        serializer = options[:serializer]
        column     = options[:encrypted_column]
        convergent = options[:convergent]

        # Get the current value of the plaintext attribute
        plaintext = read_attribute(attribute)

        # Apply the serialize to the plaintext value, if one exists
        plaintext = serializer.encode(plaintext) if serializer

        # Generate the ciphertext and store it back as an attribute
        ciphertext = Vault::Rails.encrypt(path, key, plaintext, Vault.client, convergent)

        # Write the attribute back, so that we don't have to reload the record
        # to get the ciphertext
        write_attribute(column, ciphertext)
      end

      def save(*)
        super.tap do
          changes_applied
        end
      end

      def save!(*)
        super.tap do
          changes_applied
        end
      end

      # verride the reload method to reload the Vault attributes. This will
      # ensure that we always have the most recent data from Vault when we
      # reload a record from the database.
      def reload(*)
        super.tap do
          # Unset all the instance variables to force the new data to be pulled from Vault
          self.class.__vault_attributes.each do |attribute, _|
            write_attribute(attribute, nil)
          end

          self.__vault_load_attributes!
          clear_changes_information
        end
      end
    end
  end
end
