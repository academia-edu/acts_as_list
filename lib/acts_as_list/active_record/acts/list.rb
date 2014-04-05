module ActiveRecord
  module Acts #:nodoc:
    module List #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end

      # This +acts_as+ extension provides the capabilities for sorting and reordering a number of objects in a list.
      # The class that has this specified needs to have a +position+ column defined as a float on
      # the mapped database table.
      #
      # Todo list example:
      #
      #   class TodoList < ActiveRecord::Base
      #     has_many :todo_items, order: "position"
      #   end
      #
      #   class TodoItem < ActiveRecord::Base
      #     belongs_to :todo_list
      #     acts_as_list scope: :todo_list
      #   end
      #
      #   todo_list.first.move_to_bottom
      #   todo_list.last.move_higher
      module ClassMethods
        # Configuration options are:
        #
        # * +column+ - specifies the column name to use for keeping the position float (default: +position+).
        #   The value in this column isn't semantically meaningful, only the ordering it provides.
        # * +scope+ - restricts what is to be considered a list. Given a symbol, it'll attach <tt>_id</tt>
        #   (if it hasn't already been added) and use that as the foreign key restriction. It's also possible
        #   to give it an entire string that is interpolated if you need a tighter scope than just a foreign key.
        #   Example: <tt>acts_as_list scope: 'todo_list_id = #{todo_list_id} AND completed = 0'</tt>
        # * +top_of_list+ - defines the integer used for the top of the list. Defaults to 1. Use 0 to make the collection
        #   act more like an array in its indexing.
        #
        # * +add_new_at+ - specifies whether objects get added to the :top or :bottom of the list. (default: +bottom+)
        #                   `nil` will result in new items not being added to the list on create
        def acts_as_list(options = {})
          configuration = { column: "position", scope: "1 = 1", top_of_list: 1, add_new_at: :bottom }
          configuration.update(options) if options.is_a?(Hash)

          configuration[:scope] = "#{configuration[:scope]}_id".intern if configuration[:scope].is_a?(Symbol) && configuration[:scope].to_s !~ /_id$/

          if configuration[:scope].is_a?(Symbol)
            scope_methods = %(
              validates_uniqueness_of '#{configuration[:column]}', :scope => '#{configuration[:scope].to_s}', :allow_nil => true

              def scope_condition
                self.class.send(:sanitize_sql_hash_for_conditions, { :#{configuration[:scope].to_s} => send(:#{configuration[:scope].to_s}) })
              end

              def scope_changed?
                changes.include?(scope_name.to_s)
              end
            )
          elsif configuration[:scope].is_a?(Array)
            scope_methods = %(
              validates_uniqueness_of '#{configuration[:column]}', :scope => %w(#{configuration[:scope].join(" ")}), :allow_nil => true

              def attrs
                %w(#{configuration[:scope].join(" ")}).inject({}) do |memo,column|
                  memo[column.intern] = send(column.intern); memo
                end
              end

              def scope_changed?
                (attrs.keys & changes.keys.map(&:to_sym)).any?
              end

              def scope_condition
                self.class.send(:sanitize_sql_hash_for_conditions, attrs)
              end
            )
          else
            scope_methods = %(
              def scope_condition
                "#{configuration[:scope]}"
              end

              def scope_changed?() false end
            )
          end

          class_eval <<-EOV
            include ::ActiveRecord::Acts::List::InstanceMethods

            def acts_as_list_top
              #{configuration[:top_of_list]}.to_i
            end

            def acts_as_list_class
              ::#{self.name}
            end

            def position_column
              '#{configuration[:column]}'
            end

            def scope_name
              '#{configuration[:scope]}'
            end

            def add_new_at
              '#{configuration[:add_new_at]}'
            end

            #{scope_methods}

            before_validation :check_scope, on: :update

            scope :in_list, lambda { where("#{table_name}.#{configuration[:column]} IS NOT NULL") }
          EOV

          if configuration[:add_new_at].present?
            self.send(:before_create, "add_to_list_#{configuration[:add_new_at]}", if: :not_in_list?)
          end

          # Update the given object's list according to the order of the given IDs. Returns the final list
          # of ids, which may be different from the given list if the given list was inconsistent with the database.
          define_singleton_method :update_ordered_list do |scope_param, new_ids|
            conditions =
              if scope_param.is_a?(Hash)
                scope_param
              elsif configuration[:scope].is_a?(Symbol)
                { configuration[:scope] => scope_param }
              elsif configuration[:scope].is_a?(Array) && scope_param.is_a?(Array)
                Hash[configuration[:scope].zip(scope_param)]
              else
                configuration[:scope]
              end

            records_by_id = unscoped.where(conditions).inject({}) do |memo, obj|
              memo[obj.send(primary_key)] = obj
              memo
            end

            current_ids = records_by_id.sort_by{ |id,obj| obj.send(configuration[:column]) }.map(&:first)

            new_ids &= current_ids
            new_ids += (current_ids - new_ids)

            updated_positions = {}

            # TODO Try to minimize # of updates
            new_ids.zip(current_ids).each_with_index do |(new_id_at_i, current_id_at_i), i|
              if new_id_at_i != current_id_at_i
                updated_positions[new_id_at_i] = records_by_id[current_id_at_i].send(configuration[:column])
              end
            end

            transaction do
              updated_positions.each do |id, position|
                records_by_id[id].update_attribute configuration[:column], position
              end
            end

            new_ids
          end
        end
      end

      # All the methods available to a record that has had <tt>acts_as_list</tt> specified. Each method works
      # by assuming the object to be the item in the list, so <tt>chapter.move_lower</tt> would move that chapter
      # lower in the list of all chapters. Likewise, <tt>chapter.first?</tt> would return +true+ if that chapter is
      # the first in the list of all chapters.
      module InstanceMethods
        # Insert the item at the given one-based index (defaults to the top).
        def insert_at(index = acts_as_list_top)
          insert_at_index index - acts_as_list_top
        end

        # Swap positions with the next lower item, if one exists.
        def move_lower
          swap_positions_with lower_item
        end

        # Swap positions with the next higher item, if one exists.
        def move_higher
          swap_positions_with higher_item
        end

        # Move to the bottom of the list.
        def move_to_bottom
          assume_bottom_position if in_list?
        end

        # Move to the top of the list.
        def move_to_top
          assume_top_position if in_list?
        end

        # Removes the item from the list.
        def remove_from_list
          set_list_position(nil) if in_list?
        end

        # Move the item within scope
        def move_within_scope(scope_id)
          send("#{scope_name}=", scope_id)
          save!
        end

        # Return +true+ if this object is the first in the list.
        def first?
          in_list? && send(position_column) <= top_position_in_list
        end

        # Return +true+ if this object is the last in the list.
        def last?
          in_list? && send(position_column) >= bottom_position_in_list
        end

        # Return the next higher item in the list.
        def higher_item
          higher_items.last
        end

        # Return the next n higher items in the list
        # selects all higher items by default
        def higher_items(limit=nil)
          items_above(send(position_column), limit)
        end

        # Return the next lower item in the list.
        def lower_item
          lower_items.first
        end

        # Return the next n lower items in the list
        # selects all lower items by default
        def lower_items(limit=nil)
          items_below(send(position_column), limit)
        end

        # Test if this record is in a list
        def in_list?
          !not_in_list?
        end

        def not_in_list?
          send(position_column).nil?
        end

        # Counting-from-one index in the list,
        # unless top_of_list is defined otherwise.
        def index_in_list
          higher_items.count + acts_as_list_top if in_list?
        end

        # TODO Figure out how best to do this in Rails environments which have not included the relevant gem
        # attr_protected position_column

        protected

          def set_list_position(new_position)
            write_attribute position_column, new_position
            save(validate: !persisted?)
          end

        private

          def swap_positions_with(other)
            old_position = send(position_column)
            acts_as_list_class.transaction do
              set_list_position other.send(position_column)
              other.set_list_position old_position
            end
          end

          def acts_as_list_list
            acts_as_list_class.unscoped.
              where(scope_condition)
          end

          def add_to_list_top
            self[position_column] =
              if (prior_top = top_position_in_list)
                prior_top - 1
              else
                0
              end
          end

          def add_to_list_bottom
            self[position_column] =
              if (prior_bottom = bottom_position_in_list)
                prior_bottom + 1
              else
                0
              end
          end

          # Overwrite this method to define the scope of the list changes
          def scope_condition() "1" end

          # Returns the bottom position number in the list.
          #   bottom_position_in_list    # => 2
          def bottom_position_in_list(except = nil)
            relation = acts_as_list_list
            relation = relation.where("#{self.class.primary_key} != #{except.id}") if except
            relation.maximum(position_column)
          end

          def top_position_in_list(except = nil)
            relation = acts_as_list_list
            relation = relation.where("#{self.class.primary_key} != #{except.id}") if except
            relation.minimum(position_column)
          end

          # Forces item to assume the bottom position in the list.
          def assume_bottom_position
            prior_bottom = bottom_position_in_list((self if persisted?))
            current_position = send(position_column)

            if prior_bottom.nil?
              set_list_position(0)
            elsif current_position.nil? || prior_bottom > current_position
              set_list_position(prior_bottom + 1)
            end
          end

          # Forces item to assume the top position in the list.
          def assume_top_position
            prior_top = top_position_in_list((self if persisted?))
            current_position = send(position_column)

            if prior_top.nil?
              set_list_position(0)
            elsif current_position.nil? || prior_top < current_position
              set_list_position(prior_top - 1)
            end
          end

          def insert_at_index(index)
            old_item = item_at_index index
            if old_item.nil?
              if index <= 0
                assume_top_position
              else
                assume_bottom_position
              end
            elsif old_item != self
              if not_in_list? || send(position_column) > old_item.send(position_column)
                item_above = old_item.higher_item
                if item_above.nil?
                  assume_top_position
                else
                  take_position_between old_item, item_above
                end
              else
                item_below = old_item.lower_item
                if item_below.nil?
                  assume_bottom_position
                else
                  take_position_between item_below, old_item
                end
              end
            end
          end

          def take_position_between(lower_item, upper_item)
            gap = lower_item.send(position_column) - upper_item.send(position_column)

            if gap == 0 || gap / 2.0 == 0
              # Maybe we should handle this case cleanly, but it seems more likely to indicate a bug than an actual exhaustion of floating point numbers
              raise "No gap between #{lower_item} and #{upper_item}, this is improbable"
            end

            set_list_position(upper_item.send(position_column) + gap / 2.0)
          end

          def item_at_index(index)
            acts_as_list_list.
              order("#{acts_as_list_class.table_name}.#{position_column} ASC").
              offset(index.to_i).
              first
          end

          def check_scope
            if scope_changed?
              send("add_to_list_#{add_new_at}")
            end
          end

          def items_above(position, limit=nil)
            # This is needed since we want to order DESC for purposes of the limit,
            # but then order ASC in the actual results returned.
            inner_select = acts_as_list_list.
              where("#{position_column} < ?", position).
              order("#{acts_as_list_class.table_name}.#{position_column} DESC").
              limit(limit).
              arel.
              as(acts_as_list_class.table_name)

            acts_as_list_class.
              unscoped.
              from(inner_select).
              order("#{acts_as_list_class.table_name}.#{position_column} ASC")
          end

          def items_below(position, limit=nil)
            acts_as_list_list.
              where("#{position_column} > ?", position).
              limit(limit).
              order("#{acts_as_list_class.table_name}.#{position_column} ASC")
          end

      end
    end
  end
end
