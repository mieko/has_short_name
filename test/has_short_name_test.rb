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

class HasShortNameTest < MiniTest::Unit::TestCase
  def setup
    capture_io do
      ActiveRecord::Schema.define(version: 1) do
        create_table :base_tables do |t|
          t.column :type, :string
          t.column :name, :string
          t.column :short_name, :string
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
    assert_equal "Mike", u.short_name
  end

end
