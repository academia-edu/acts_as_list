module Shared
  module ZeroBased
    def setup
       (1..4).each { |counter| ZeroBasedMixin.create! parent_id: 5 }
    end

    def test_insert
      new = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 0, new.index_in_list
      assert new.first?
      assert new.last?

      new = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list
      assert !new.first?
      assert new.last?

      new = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 2, new.index_in_list
      assert !new.first?
      assert new.last?

      new = ZeroBasedMixin.create(parent_id: 0)
      assert_equal 0, new.index_in_list
      assert new.first?
      assert new.last?

      new = ZeroBasedMixin.create(parent_id: 1, pos: -500)
      assert_equal 0, new.index_in_list
      assert new.first?
      assert new.last?
    end

    def test_reordering
      assert_equal [1, 2, 3, 4], ZeroBasedMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.move_lower
      assert_equal [1, 3, 2, 4], ZeroBasedMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.move_higher
      assert_equal [1, 2, 3, 4], ZeroBasedMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 1).first.move_to_bottom
      assert_equal [2, 3, 4, 1], ZeroBasedMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 1).first.move_to_top
      assert_equal [1, 2, 3, 4], ZeroBasedMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 2).first.move_to_bottom
      assert_equal [1, 3, 4, 2], ZeroBasedMixin.where(parent_id: 5).order('pos').map(&:id)

      ListMixin.where(id: 4).first.move_to_top
      assert_equal [4, 1, 3, 2], ZeroBasedMixin.where(parent_id: 5).order('pos').map(&:id)
    end

    def test_insert_at
      new = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 0, new.index_in_list

      new = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list

      new = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 2, new.index_in_list

      new4 = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 3, new4.index_in_list

      new4.insert_at(2)
      assert_equal 2, new4.index_in_list

      new.reload
      assert_equal 3, new.index_in_list

      new.insert_at(2)
      assert_equal 2, new.index_in_list

      new4.reload
      assert_equal 3, new4.index_in_list

      new5 = ZeroBasedMixin.create(parent_id: 20)
      assert_equal 4, new5.index_in_list

      new5.insert_at(1)
      assert_equal 1, new5.index_in_list

      new4.reload
      assert_equal 4, new4.index_in_list
    end
  end
end
