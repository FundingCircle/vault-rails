# Force ther original JoinPart to load
require 'active_record/associations/join_dependency/join_part'

module ActiveRecord
  module Associations
    class JoinDependency
      class JoinPart
        # Prevent virtual attributes from being included in JOIN sql queries.
        # This will work with both ActiveRecord 4 an 5 because in the original
        # implementation this methos is delegated to the base class - the model.
        def column_names
          column_names = base_klass.column_names

          if base_klass.methods.include? :persistable_attribute_names
            column_names = column_names & base_klass.persistable_attribute_names
          end

          column_names
        end
      end
    end
  end
end
