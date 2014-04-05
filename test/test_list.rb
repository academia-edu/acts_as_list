# NOTE: following now done in helper.rb (better Readability)
require 'helper'

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false

def setup_db(position_options = {})
  # AR caches columns options like defaults etc. Clear them!
  ActiveRecord::Base.connection.schema_cache.clear!
  ActiveRecord::Schema.define(version: 1) do
    create_table :mixins do |t|
      t.column :pos, :float, position_options
      t.column :active, :boolean, default: true
      t.column :parent_id, :integer
      t.column :parent_type, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end
end

def setup_db_with_default
  setup_db default: 0
end

# Returns true if ActiveRecord is rails3,4 version
def rails_3
  defined?(ActiveRecord::VERSION) && ActiveRecord::VERSION::MAJOR >= 3
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Mixin < ActiveRecord::Base
  self.table_name = 'mixins'
end

class ListMixin < Mixin
  acts_as_list column: "pos", scope: :parent
end

class ListMixinSub1 < ListMixin
end

class ListMixinSub2 < ListMixin
  if rails_3
    validates :pos, presence: true
  else
    validates_presence_of :pos
  end
end

class ListWithStringScopeMixin < Mixin
  acts_as_list column: "pos", scope: 'parent_id = #{parent_id}'
end

class ArrayScopeListMixin < Mixin
  acts_as_list column: "pos", scope: [:parent_id, :parent_type]
end

class ZeroBasedMixin < Mixin
  acts_as_list column: "pos", top_of_list: 0, scope: [:parent_id]
end

class DefaultScopedMixin < Mixin
  acts_as_list column: "pos"
  default_scope { order('pos ASC') }
end

class DefaultScopedWhereMixin < Mixin
  acts_as_list column: "pos"
  default_scope { order('pos ASC').where(active: true) }

  def self.for_active_false_tests
    unscoped.order('pos ASC').where(active: false)
  end
end

class TopAdditionMixin < Mixin
  acts_as_list column: "pos", add_new_at: :top, scope: :parent_id
end

class NoAdditionMixin < Mixin
  acts_as_list column: "pos", add_new_at: nil, scope: :parent_id
end

class ActsAsListTestCase < MiniTest::Unit::TestCase
  # No default test required a this class is abstract.
  # Need for test/unit.
  undef_method :default_test if method_defined?(:default_test)

  def teardown
    teardown_db
  end
end

class ZeroBasedTest < ActsAsListTestCase
  include Shared::ZeroBased

  def setup
    setup_db
    super
  end
end

class ZeroBasedTestWithDefault < ActsAsListTestCase
  include Shared::ZeroBased

  def setup
    setup_db_with_default
    super
  end
end

class ListTest < ActsAsListTestCase
  include Shared::List

  def setup
    setup_db
    super
  end
end

class ListTestWithDefault < ActsAsListTestCase
  include Shared::List

  def setup
    setup_db_with_default
    super
  end
end

class ListSubTest < ActsAsListTestCase
  include Shared::ListSub

  def setup
    setup_db
    super
  end
end

class ListSubTestWithDefault < ActsAsListTestCase
  include Shared::ListSub

  def setup
    setup_db_with_default
    super
  end
end

class ArrayScopeListTest < ActsAsListTestCase
  include Shared::ArrayScopeList

  def setup
    setup_db
    super
  end
end

class ArrayScopeListTestWithDefault < ActsAsListTestCase
  include Shared::ArrayScopeList

  def setup
    setup_db_with_default
    super
  end
end

class DefaultScopedTest < ActsAsListTestCase
  def setup
    setup_db
    (1..4).each { |counter| DefaultScopedMixin.create!({pos: counter}) }
  end

  def test_insert
    new = DefaultScopedMixin.create
    assert_equal 5, new.index_in_list
    assert !new.first?
    assert new.last?

    new = DefaultScopedMixin.create
    assert_equal 6, new.index_in_list
    assert !new.first?
    assert new.last?

    new = DefaultScopedMixin.create
    assert_equal 7, new.index_in_list
    assert !new.first?
    assert new.last?
  end

  def test_reordering
    assert_equal [1, 2, 3, 4], DefaultScopedMixin.all.map(&:id)

    DefaultScopedMixin.where(id: 2).first.move_lower
    assert_equal [1, 3, 2, 4], DefaultScopedMixin.all.map(&:id)

    DefaultScopedMixin.where(id: 2).first.move_higher
    assert_equal [1, 2, 3, 4], DefaultScopedMixin.all.map(&:id)

    DefaultScopedMixin.where(id: 1).first.move_to_bottom
    assert_equal [2, 3, 4, 1], DefaultScopedMixin.all.map(&:id)

    DefaultScopedMixin.where(id: 1).first.move_to_top
    assert_equal [1, 2, 3, 4], DefaultScopedMixin.all.map(&:id)

    DefaultScopedMixin.where(id: 2).first.move_to_bottom
    assert_equal [1, 3, 4, 2], DefaultScopedMixin.all.map(&:id)

    DefaultScopedMixin.where(id: 4).first.move_to_top
    assert_equal [4, 1, 3, 2], DefaultScopedMixin.all.map(&:id)
  end

  def test_insert_at
    new = DefaultScopedMixin.create
    assert_equal 5, new.index_in_list

    new = DefaultScopedMixin.create
    assert_equal 6, new.index_in_list

    new = DefaultScopedMixin.create
    assert_equal 7, new.index_in_list

    new4 = DefaultScopedMixin.create
    assert_equal 8, new4.index_in_list

    new4.insert_at(2)
    assert_equal 2, new4.index_in_list

    new.reload
    assert_equal 8, new.index_in_list

    new.insert_at(2)
    assert_equal 2, new.index_in_list

    new4.reload
    assert_equal 3, new4.index_in_list

    new5 = DefaultScopedMixin.create
    assert_equal 9, new5.index_in_list

    new5.insert_at(1)
    assert_equal 1, new5.index_in_list

    new4.reload
    assert_equal 4, new4.index_in_list
  end

  def test_update_position
    assert_equal [1, 2, 3, 4], DefaultScopedMixin.all.map(&:id)
    DefaultScopedMixin.where(id: 2).first.insert_at(4)
    assert_equal [1, 3, 4, 2], DefaultScopedMixin.all.map(&:id)
    DefaultScopedMixin.where(id: 2).first.insert_at(2)
    assert_equal [1, 2, 3, 4], DefaultScopedMixin.all.map(&:id)
    DefaultScopedMixin.where(id: 1).first.insert_at(4)
    assert_equal [2, 3, 4, 1], DefaultScopedMixin.all.map(&:id)
    DefaultScopedMixin.where(id: 1).first.insert_at(1)
    assert_equal [1, 2, 3, 4], DefaultScopedMixin.all.map(&:id)
  end
end

class DefaultScopedWhereTest < ActsAsListTestCase
  def setup
    setup_db
    (1..4).each { |counter| DefaultScopedWhereMixin.create! pos: counter, active: false }
  end

  def test_insert
    new = DefaultScopedWhereMixin.create
    assert_equal 5, new.index_in_list
    assert !new.first?
    assert new.last?

    new = DefaultScopedWhereMixin.create
    assert_equal 6, new.index_in_list
    assert !new.first?
    assert new.last?

    new = DefaultScopedWhereMixin.create
    assert_equal 7, new.index_in_list
    assert !new.first?
    assert new.last?
  end

  def test_reordering
    assert_equal [1, 2, 3, 4], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)

    DefaultScopedWhereMixin.for_active_false_tests.where(id: 2).first.move_lower
    assert_equal [1, 3, 2, 4], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)

    DefaultScopedWhereMixin.for_active_false_tests.where(id: 2).first.move_higher
    assert_equal [1, 2, 3, 4], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)

    DefaultScopedWhereMixin.for_active_false_tests.where(id: 1).first.move_to_bottom
    assert_equal [2, 3, 4, 1], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)

    DefaultScopedWhereMixin.for_active_false_tests.where(id: 1).first.move_to_top
    assert_equal [1, 2, 3, 4], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)

    DefaultScopedWhereMixin.for_active_false_tests.where(id: 2).first.move_to_bottom
    assert_equal [1, 3, 4, 2], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)

    DefaultScopedWhereMixin.for_active_false_tests.where(id: 4).first.move_to_top
    assert_equal [4, 1, 3, 2], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)
  end

  def test_insert_at
    new = DefaultScopedWhereMixin.create
    assert_equal 5, new.index_in_list

    new = DefaultScopedWhereMixin.create
    assert_equal 6, new.index_in_list

    new = DefaultScopedWhereMixin.create
    assert_equal 7, new.index_in_list

    new4 = DefaultScopedWhereMixin.create
    assert_equal 8, new4.index_in_list

    new4.insert_at(2)
    assert_equal 2, new4.index_in_list

    new.reload
    assert_equal 8, new.index_in_list

    new.insert_at(2)
    assert_equal 2, new.index_in_list

    new4.reload
    assert_equal 3, new4.index_in_list

    new5 = DefaultScopedWhereMixin.create
    assert_equal 9, new5.index_in_list

    new5.insert_at(1)
    assert_equal 1, new5.index_in_list

    new4.reload
    assert_equal 4, new4.index_in_list
  end

  def test_update_position
    assert_equal [1, 2, 3, 4], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)
    DefaultScopedWhereMixin.for_active_false_tests.where(id: 2).first.insert_at(4)
    assert_equal [1, 3, 4, 2], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)
    DefaultScopedWhereMixin.for_active_false_tests.where(id: 2).first.insert_at(2)
    assert_equal [1, 2, 3, 4], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)
    DefaultScopedWhereMixin.for_active_false_tests.where(id: 1).first.insert_at(4)
    assert_equal [2, 3, 4, 1], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)
    DefaultScopedWhereMixin.for_active_false_tests.where(id: 1).first.insert_at(1)
    assert_equal [1, 2, 3, 4], DefaultScopedWhereMixin.for_active_false_tests.map(&:id)
  end

end

class MultiDestroyTest < ActsAsListTestCase

  def setup
    setup_db
  end

  # example:
  #
  #   class TodoList < ActiveRecord::Base
  #     has_many :todo_items, order: "position"
  #     accepts_nested_attributes_for :todo_items, allow_destroy: true
  #   end
  #
  #   class TodoItem < ActiveRecord::Base
  #     belongs_to :todo_list
  #     acts_as_list scope: :todo_list
  #   end
  #
  # Assume that there are three items.
  # The user mark two items as deleted, click save button, form will be post:
  #
  # todo_list.todo_items_attributes = [
  #   {id: 1, _destroy: true},
  #   {id: 2, _destroy: true}
  # ]
  #
  # Save toto_list, the position of item #3 should eql 1.
  #
  def test_destroy
    new1 = DefaultScopedMixin.create
    assert_equal 1, new1.index_in_list

    new2 = DefaultScopedMixin.create
    assert_equal 2, new2.index_in_list

    new3 = DefaultScopedMixin.create
    assert_equal 3, new3.index_in_list

    new1.destroy
    new2.destroy
    new3.reload
    assert_equal 1, new3.index_in_list
  end
end

class TopAdditionTest < ActsAsListTestCase
  include Shared::TopAddition

  def setup
    setup_db
    super
  end
end

class TopAdditionTestWithDefault < ActsAsListTestCase
  include Shared::TopAddition

  def setup
    setup_db_with_default
    super
  end
end

class NoAdditionTest < ActsAsListTestCase
  include Shared::NoAddition

  def setup
    setup_db
    super
  end
end

class MultipleListsTest < ActsAsListTestCase
  def setup
    setup_db
    (1..4).each { |counter| ListMixin.create! :parent_id => 1}
    (1..4).each { |counter| ListMixin.create! :parent_id => 2}
  end

  def test_check_scope_order
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 1).order(:pos).map(&:id)
    assert_equal [5, 6, 7, 8], ListMixin.where(:parent_id => 2).order(:pos).map(&:id)
    ListMixin.find(4).update_attributes(:parent_id => 2)
    assert_equal [1, 2, 3], ListMixin.where(:parent_id => 1).order(:pos).map(&:id)
    assert_equal [5, 6, 7, 8, 4], ListMixin.where(:parent_id => 2).order(:pos).map(&:id)
  end

  def test_check_scope_position
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 1).map(&:index_in_list)
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 2).map(&:index_in_list)
    ListMixin.find(4).update_attributes(:parent_id => 2)
    assert_equal [1, 2, 3], ListMixin.where(:parent_id => 1).order(:pos).map(&:index_in_list)
    assert_equal [1, 2, 3, 4, 5], ListMixin.where(:parent_id => 2).order(:pos).map(&:index_in_list)
  end
end

class BulkReorderingTest < ActsAsListTestCase
  def setup
    setup_db
    (1..4).each { |counter| ListMixin.create! parent_id: 5 }
  end

  def assert_reordering(input, expected)
    res = ListMixin.update_ordered_list 5, input
    assert_equal expected, res
    assert_equal expected, ListMixin.where(parent_id: 5).order(:pos).map(&:id)
  end

  def test_reorders_elements_based_on_the_given_list
    assert_reordering [4, 2, 3, 1], [4, 2, 3, 1]
  end

  def test_reversal
    assert_reordering [4, 3, 2, 1], [4, 3, 2, 1]
  end

  def test_one_swap
    assert_reordering [1, 3, 2, 4], [1, 3, 2, 4]
  end

  def test_when_the_user_does_not_provide_a_complete_reordering
    assert_reordering [4, 2, 1], [4, 2, 1, 3]
  end

  def test_when_the_user_provides_nonexistent_elements
    assert_reordering [5, 4, 3, 2, 1], [4, 3, 2, 1]
  end

  def test_empty_reordering_preserves_existing_order
    assert_reordering [], [1, 2, 3, 4]
  end
end

class BulkReorderingTopAdditionTest < ActsAsListTestCase
  def setup
    setup_db
    (1..4).each { |counter| TopAdditionMixin.create! parent_id: 5 }
  end

  def assert_reordering(input, expected)
    res = TopAdditionMixin.update_ordered_list 5, input
    assert_equal expected, res
    assert_equal expected, TopAdditionMixin.where(parent_id: 5).order(:pos).map(&:id)
  end

  def test_reorders_elements_based_on_the_given_list
    assert_reordering [1, 2, 4, 3], [1, 2, 4, 3]
  end

  def test_when_the_user_does_not_provide_a_complete_reordering
    assert_reordering [1, 4, 3], [1, 4, 3, 2]
  end

  def test_when_the_user_provides_nonexistent_elements
    assert_reordering [5, 1, 2, 4, 3], [1, 2, 4, 3]
  end

  def test_empty_reordering_preserves_existing_order
    assert_reordering [], [4, 3, 2, 1]
  end
end

class MultipleListsArrayScopeTest < ActsAsListTestCase
  def setup
    setup_db
    (1..4).each { |counter| ArrayScopeListMixin.create! :parent_id => 1, :parent_type => 'anything'}
    (1..4).each { |counter| ArrayScopeListMixin.create! :parent_id => 2, :parent_type => 'something'}
    (1..4).each { |counter| ArrayScopeListMixin.create! :parent_id => 3, :parent_type => 'anything'}
  end

  def test_order_after_all_scope_properties_are_changed
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [5, 6, 7, 8], ArrayScopeListMixin.where(:parent_id => 2, :parent_type => 'something').order(:pos).map(&:id)
    ArrayScopeListMixin.find(2).update_attributes(:parent_id => 2, :parent_type => 'something')
    assert_equal [1, 3, 4], ArrayScopeListMixin.where(:parent_id => 1,:parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [5, 6, 7, 8, 2], ArrayScopeListMixin.where(:parent_id => 2,:parent_type => 'something').order(:pos).map(&:id)
  end

  def test_position_after_all_scope_properties_are_changed
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').map(&:index_in_list)
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 2, :parent_type => 'something').map(&:index_in_list)
    ArrayScopeListMixin.find(4).update_attributes(:parent_id => 2, :parent_type => 'something')
    assert_equal [1, 2, 3], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:index_in_list)
    assert_equal [1, 2, 3, 4, 5], ArrayScopeListMixin.where(:parent_id => 2, :parent_type => 'something').order(:pos).map(&:index_in_list)
  end

  def test_order_after_one_scope_property_is_changed
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [9, 10, 11, 12], ArrayScopeListMixin.where(:parent_id => 3, :parent_type => 'anything').order(:pos).map(&:id)
    ArrayScopeListMixin.find(2).update_attributes(:parent_id => 3)
    assert_equal [1, 3, 4], ArrayScopeListMixin.where(:parent_id => 1,:parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [9, 10, 11, 12, 2], ArrayScopeListMixin.where(:parent_id => 3,:parent_type => 'anything').order(:pos).map(&:id)
  end

  def test_position_after_one_scope_property_is_changed
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').map(&:index_in_list)
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 3, :parent_type => 'anything').map(&:index_in_list)
    ArrayScopeListMixin.find(4).update_attributes(:parent_id => 3)
    assert_equal [1, 2, 3], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:index_in_list)
    assert_equal [1, 2, 3, 4, 5], ArrayScopeListMixin.where(:parent_id => 3, :parent_type => 'anything').order(:pos).map(&:index_in_list)
  end

  def test_order_after_moving_to_empty_list
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [], ArrayScopeListMixin.where(:parent_id => 4, :parent_type => 'anything').order(:pos).map(&:id)
    ArrayScopeListMixin.find(2).update_attributes(:parent_id => 4)
    assert_equal [1, 3, 4], ArrayScopeListMixin.where(:parent_id => 1,:parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [2], ArrayScopeListMixin.where(:parent_id => 4,:parent_type => 'anything').order(:pos).map(&:id)
  end

  def test_position_after_moving_to_empty_list
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').map(&:index_in_list)
    assert_equal [], ArrayScopeListMixin.where(:parent_id => 4, :parent_type => 'anything').map(&:index_in_list)
    ArrayScopeListMixin.find(2).update_attributes(:parent_id => 4)
    assert_equal [1, 2, 3], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:index_in_list)
    assert_equal [1], ArrayScopeListMixin.where(:parent_id => 4, :parent_type => 'anything').order(:pos).map(&:index_in_list)
  end

  def test_bulk_reordering
    assert_equal [1, 2, 3, 4], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [5, 6, 7, 8], ArrayScopeListMixin.where(:parent_id => 2, :parent_type => 'something').order(:pos).map(&:id)
    res = ArrayScopeListMixin.update_ordered_list([1, 'anything'], [4, 1, 3, 2])
    assert_equal [4, 1, 3, 2], res
    assert_equal [4, 1, 3, 2], ArrayScopeListMixin.where(:parent_id => 1, :parent_type => 'anything').order(:pos).map(&:id)
    assert_equal [5, 6, 7, 8], ArrayScopeListMixin.where(:parent_id => 2, :parent_type => 'something').order(:pos).map(&:id)
  end
end
