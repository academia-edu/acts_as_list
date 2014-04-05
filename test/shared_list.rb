module Shared
  module List
    def setup
      (1..4).each do |counter|
        node = ListMixin.new parent_id: 5
        node.pos = counter
        node.save!
      end
    end

    def test_reordering
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.move_lower
      assert_equal [1, 3, 2, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.move_higher
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 1).first.move_to_bottom
      assert_equal [2, 3, 4, 1], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 1).first.move_to_top
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.move_to_bottom
      assert_equal [1, 3, 4, 2], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 4).first.move_to_top
      assert_equal [4, 1, 3, 2], ListMixin.where(parent_id: 5).order('pos').map(&:id)
    end

    def test_move_to_bottom_with_next_to_last_item
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)
      ListMixin.where(id: 3).first.move_to_bottom
      assert_equal [1, 2, 4, 3], ListMixin.where(parent_id: 5).order('pos').map(&:id)
    end

    def test_next_prev
      assert_equal ListMixin.where(id: 2).first, ListMixin.where(id: 1).first.lower_item
      assert_nil ListMixin.where(id: 1).first.higher_item
      assert_equal ListMixin.where(id: 3).first, ListMixin.where(id: 4).first.higher_item
      assert_nil ListMixin.where(id: 4).first.lower_item
    end

    def test_injection
      item = ListMixin.new(parent_id: 1)
      assert_equal '"mixins"."parent_id" = 1', item.scope_condition
      assert_equal "pos", item.position_column
    end

    def test_insert
      new = ListMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list
      assert new.first?
      assert new.last?

      new = ListMixin.create(parent_id: 20)
      assert_equal 2, new.index_in_list
      assert !new.first?
      assert new.last?

      new = ListMixin.create(parent_id: 20)
      assert_equal 3, new.index_in_list
      assert !new.first?
      assert new.last?

      new = ListMixin.create(parent_id: 0)
      assert_equal 1, new.index_in_list
      assert new.first?
      assert new.last?
    end

    def test_insert_at
      new = ListMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list

      new = ListMixin.create(parent_id: 20)
      assert_equal 2, new.index_in_list

      new = ListMixin.create(parent_id: 20)
      assert_equal 3, new.index_in_list

      new4 = ListMixin.create(parent_id: 20)
      assert_equal 4, new4.index_in_list

      new4.insert_at(3)
      assert_equal 3, new4.index_in_list

      new.reload
      assert_equal 4, new.index_in_list

      new.insert_at(2)
      assert_equal 2, new.index_in_list

      new4.reload
      assert_equal 4, new4.index_in_list

      new5 = ListMixin.create(parent_id: 20)
      assert_equal 5, new5.index_in_list

      new5.insert_at(1)
      assert_equal 1, new5.index_in_list

      new4.reload
      assert_equal 5, new4.index_in_list
    end

    def test_delete_middle
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.destroy

      assert_equal [1, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      assert_equal 1, ListMixin.where(id: 1).first.index_in_list
      assert_equal 2, ListMixin.where(id: 3).first.index_in_list
      assert_equal 3, ListMixin.where(id: 4).first.index_in_list

      ListMixin.where(id: 1).first.destroy

      assert_equal [3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      assert_equal 1, ListMixin.where(id: 3).first.index_in_list
      assert_equal 2, ListMixin.where(id: 4).first.index_in_list
    end

    def test_with_string_based_scope
      new = ListWithStringScopeMixin.create(parent_id: 500)
      assert_equal 1, new.index_in_list
      assert new.first?
      assert new.last?
    end

    def test_nil_scope
      new1, new2, new3 = ListMixin.create, ListMixin.create, ListMixin.create
      new2.move_higher
      assert_equal [new2, new1, new3], ListMixin.where(parent_id: nil).order('pos')
    end

    def test_update_position_when_scope_changes
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)
      parent = ListMixin.create(id: 6)

      ListMixin.where(id: 2).first.move_within_scope(6)

      assert_equal 1, ListMixin.where(id: 2).first.index_in_list

      assert_equal [1, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      assert_equal 1, ListMixin.where(id: 1).first.index_in_list
      assert_equal 2, ListMixin.where(id: 3).first.index_in_list
      assert_equal 3, ListMixin.where(id: 4).first.index_in_list

      ListMixin.where(id: 2).first.move_within_scope(5)
      assert_equal [1, 3, 4, 2], ListMixin.where(parent_id: 5).order('pos').map(&:id)
    end

    def test_remove_from_list_should_then_fail_in_list?
      assert_equal true, ListMixin.where(id: 1).first.in_list?
      ListMixin.where(id: 1).first.remove_from_list
      assert_equal false, ListMixin.where(id: 1).first.in_list?
    end

    def test_remove_from_list_should_set_position_to_nil
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.remove_from_list

      assert_equal [2, 1, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      assert_equal 1,   ListMixin.where(id: 1).first.index_in_list
      assert_equal nil, ListMixin.where(id: 2).first.index_in_list
      assert_equal 2,   ListMixin.where(id: 3).first.index_in_list
      assert_equal 3,   ListMixin.where(id: 4).first.index_in_list
    end

    def test_remove_before_destroy_does_not_shift_lower_items_twice
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.remove_from_list
      ListMixin.where(id: 2).first.destroy

      assert_equal [1, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      assert_equal 1, ListMixin.where(id: 1).first.index_in_list
      assert_equal 2, ListMixin.where(id: 3).first.index_in_list
      assert_equal 3, ListMixin.where(id: 4).first.index_in_list
    end

    def test_adding_new_record_adds_to_bottom
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      new = ListMixin.create(parent_id: 5)
      assert_equal 5, new.index_in_list
      assert !new.first?
      assert new.last?

      assert_equal [1, 2, 3, 4, 5], ListMixin.where(parent_id: 5).order('pos').map(&:id)
    end

    def test_insert_at_adds_new_record_to_given_position
      assert_equal [1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      new = ListMixin.new(parent_id: 5)
      new.insert_at 1
      assert_equal 1, new.index_in_list
      assert new.first?
      assert !new.last?

      assert_equal [5, 1, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)

      new = ListMixin.new(parent_id: 5)
      new.insert_at 3
      assert_equal 3, new.index_in_list
      assert !new.first?
      assert !new.last?

      assert_equal [5, 1, 6, 2, 3, 4], ListMixin.where(parent_id: 5).order('pos').map(&:id)
    end
  end
end
