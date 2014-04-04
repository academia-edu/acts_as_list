module Shared
  module TopAddition
    def setup
      (1..4).each { |counter|
        TopAdditionMixin.create! parent_id: 5
      }
    end

    def test_reordering
      assert_equal [4, 3, 2, 1], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      TopAdditionMixin.where(id: 2).first.move_lower
      assert_equal [4, 3, 1, 2], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      TopAdditionMixin.where(id: 2).first.move_higher
      assert_equal [4, 3, 2, 1], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      TopAdditionMixin.where(id: 1).first.move_to_bottom
      assert_equal [4, 3, 2, 1], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      TopAdditionMixin.where(id: 1).first.move_to_top
      assert_equal [1, 4, 3, 2], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      TopAdditionMixin.where(id: 2).first.move_to_bottom
      assert_equal [1, 4, 3, 2], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      TopAdditionMixin.where(id: 4).first.move_to_top
      assert_equal [4, 1, 3, 2], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)
    end

    def test_injection
      item = TopAdditionMixin.new(parent_id: 1)
      assert_equal '"mixins"."parent_id" = 1', item.scope_condition
      assert_equal "pos", item.position_column
    end

    def test_insert
      new = TopAdditionMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list
      assert new.first?
      assert new.last?

      new = TopAdditionMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list
      assert new.first?
      assert !new.last?

      new = TopAdditionMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list
      assert new.first?
      assert !new.last?

      new = TopAdditionMixin.create(parent_id: 0)
      assert_equal 1, new.index_in_list
      assert new.first?
      assert new.last?
    end

    def test_insert_at
      new = TopAdditionMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list

      new = TopAdditionMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list

      new = TopAdditionMixin.create(parent_id: 20)
      assert_equal 1, new.index_in_list

      new4 = TopAdditionMixin.create(parent_id: 20)
      assert_equal 1, new4.index_in_list

      new4.insert_at(3)
      assert_equal 3, new4.index_in_list
    end

    def test_delete_middle
      assert_equal [4, 3, 2, 1], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      TopAdditionMixin.where(id: 2).first.destroy

      assert_equal [4, 3, 1], TopAdditionMixin.where(parent_id: 5).order('pos').map(&:id)

      assert_equal 3, TopAdditionMixin.where(id: 1).first.index_in_list
      assert_equal 2, TopAdditionMixin.where(id: 3).first.index_in_list
      assert_equal 1, TopAdditionMixin.where(id: 4).first.index_in_list
    end

  end
end
