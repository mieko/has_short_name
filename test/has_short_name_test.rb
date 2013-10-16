require 'minitest/unit'
require 'minitest/pride'
require 'minitest/autorun'
require 'active_record'
require 'has_short_name'

ActiveRecord::Base.establish_connection adapter:  'sqlite3',
                                        database: ':memory:'

class BaseTable < ActiveRecord::Base
end

class NoMixin < BaseTable
end

class WithMixin < BaseTable
  has_short_name
end

class User < BaseTable
  has_short_name
end

class ManOrMachine < BaseTable
  has_short_name only: ->(m) { m.human }
end

class HasShortNameTest < MiniTest::Unit::TestCase
  def setup
    capture_io do
      ActiveRecord::Schema.define(version: 1) do
        create_table :base_tables do |t|
          t.column :type, :string
          t.column :name, :string
          t.column :short_name, :string
          t.column :human, :boolean, null: false, default: true
        end
      end
    end
  end

  def teardown
    capture_io do
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
  end

  def all(model = User)
    model.all.order(:id).pluck(:short_name)
  end

  def test_hook_was_included
    # On AR models which has_short_name wasn't called, we shouldn't
    # have the ClassMethods mixins
    assert_kind_of HasShortName::ARHook, NoMixin
    refute_kind_of HasShortName::ClassMethods, NoMixin
  end

  def test_bootstrap_handoff
    # It should still have the bootstrap
    assert_kind_of HasShortName::ARHook, WithMixin
    assert_kind_of HasShortName::ClassMethods, WithMixin
  end

  def test_basic_functionality
    u = User.create!(name: 'Mike Owens')
    assert_equal 'Mike', u.short_name
  end

  def test_change_name
    u = User.create!(name: 'Mike Owens')
    assert_equal 'Mike', u.short_name

    u.update!(name: 'Bobby Bobberson')
    assert_equal 'Bobby', u.short_name
  end

  def test_explicit_short_name
    u = User.create!(name: 'Mike Owens', short_name: 'Miguel')
    assert_equal "Miguel", u.short_name
  end

  def test_duplicates
    u0 = User.create!(name: 'Leah Johnson')
    u1 = User.create!(name: 'Mike Owens')
    u2 = User.create!(name: 'Mike Mikerson')
    assert_equal "Leah", u0.short_name
    assert_equal "Mike", u1.short_name
    assert_equal "Mike M.", u2.short_name

    User.adjust_short_names!
    u0 = User.find_by!(name: 'Leah Johnson')
    u1 = User.find_by!(name: 'Mike Owens')
    u2 = User.find_by!(name: 'Mike Mikerson')

    assert_equal "Leah", u0.short_name
    assert_equal "Mike O.", u1.short_name
    assert_equal "Mike M.", u2.short_name
  end

  def test_bailout
    u1 = User.create!(name: 'Mike Owens')
    u2 = User.create!(name: 'Mike Otherface')
    User.adjust_short_names!
    u1 = User.find_by!(name: 'Mike Owens')
    u2 = User.find_by!(name: 'Mike Otherface')

    assert_equal "Mike Owens", u1.short_name
    assert_equal "Mike Otherface", u2.short_name
  end

  def test_unresolvable
    u1 = User.create!(name: 'Mike Owens')
    u2 = User.create!(name: 'Mike Owens')
    ids = [u1, u2]
    User.adjust_short_names!
    u1 = User.find(ids[0])
    u2 = User.find(ids[1])

    assert_equal "Mike Owens", u1.short_name
    assert_equal "Mike Owens", u2.short_name
  end

  def test_third_level
    User.create!(name: 'Mike Owens')
    User.create!(name: 'Mike Mikerson')
    User.create!(name: 'Mike Miller')
    User.create!(name: 'Mike Tyson')
    User.adjust_short_names!

    assert_equal ['Mike O.', 'Mike Mikerson', 'Mike Miller', 'Mike T.'], all
  end

  def test_mc_replacement
    User.create!(name: 'Bobby Miller')
    User.create!(name: 'Bobby McDonald')
    User.create!(name: 'Bobby McDennis')
    User.create!(name: 'Bobby MacTrollface')
    User.create!(name: 'Bobby Bobberson')
    User.create!(name: 'Bobby')
    User.adjust_short_names!
    assert_equal [ 'Bobby M.', 'Bobby McDonald', 'Bobby McDennis',
                   'Bobby MacT.', 'Bobby B.', 'Bobby'], all
  end


  def test_updates_with_name
    u = User.create!(name: 'Mike Owens')
    assert_equal 'Mike', u.short_name

    u.update! name: 'Bobby Bobberson'
    assert_equal 'Bobby', u.short_name

    u.update name: 'Mitch Hedberg', short_name: 'Tucson'
    assert_equal 'Tucson', u.short_name

    u.update name: 'Mike Owens'
    assert_equal 'Mike', u.short_name
  end

  def test_only_predicate
    u = ManOrMachine.create!(name: 'Mike Owens')
    assert_equal 'Mike', u.short_name

    u2 = ManOrMachine.create!(name: 'Lt. Commander Data', human: false)
    assert_equal 'Lt. Commander Data', u2.short_name

    # Make sure it's used properly in batch
    User.adjust_short_names!
    assert_equal ['Mike', 'Lt. Commander Data'], all(ManOrMachine)
  end

  def test_blank_only_adjust
    ManOrMachine.create!(name: 'Mike Owens')
    ManOrMachine.create!(name: 'Leah Johnson')
    ManOrMachine.create!(name: 'Lt. Commander Data', human: false)
    ManOrMachine.update_all(short_name: nil)
    assert_equal [true, true, false],ManOrMachine.all.order(:id).pluck(:human)

    ManOrMachine.adjust_short_names!


    assert_equal ['Mike', 'Leah', 'Lt. Commander Data'], all(ManOrMachine)
  end
end
