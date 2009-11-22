# encoding: UTF-8
require File.join(File.dirname(__FILE__), 'test_helper')

class PermalinkFuTest < Test::Unit::TestCase
  @@samples = {
    'This IS a Tripped out title!!.!1  (well/ not really)'.freeze => 'this-is-a-tripped-out-title1-well-not-really'.freeze,
    '////// meph1sto r0x ! \\\\\\'.freeze => 'meph1sto-r0x'.freeze,
    'āčēģīķļņū'.freeze => 'acegiklnu'.freeze,
    '中文測試 chinese text'.freeze => 'chinese-text'.freeze,
    'fööbär'.freeze => 'foobar'.freeze
  }

  @@extra = { 'some-)()()-ExtRa!/// .data==?>    to \/\/test'.freeze => 'some-extra-data-to-test'.freeze }

  def test_basemodel
    @m = BaseModel.new
    assert @m.valid?
    assert_equal @m.id, nil
    assert_equal @m.title, nil
    assert_equal @m.permalink, nil
    assert_equal @m.extra, nil
    assert_equal @m.foo, nil
  end

  def test_set_new_permalink_attributes_on_sub_class
    @m = ClassModel.new
    @m.title = 'foo'
    @m.extra = 'bar'
    assert @m.valid?
    assert_equal @m.permalink, 'foo'
    
    @m = SubClassHasPermalinkModel.new
    @m.title = 'foo'
    @m.extra = 'bar'
    assert @m.valid?
    assert_equal @m.permalink, 'foo-bar'
  end
  
  def test_should_not_inherit_permalink_attributes
    @m = SubClassNoPermalinkModel.new
    @m.title = 'foo'
    assert @m.valid?
    assert_equal @m.permalink, nil
  end

  def test_should_escape_permalinks
    @@samples.each do |from, to|
      assert_equal to, PermalinkFu.escape(from)
    end
  end
  
  def test_should_escape_activerecord_model
    @m = MockModel.new
    @@samples.each do |from, to|
      @m.title = from; @m.permalink = nil
      assert @m.valid?
      assert_equal to, @m.permalink
    end
  end
  
  def test_should_escape_activerecord_model_with_existing_permalink
    @m = MockModel.new
    @@samples.each do |from, to|
      @m.title = 'whatever'; @m.permalink = from
      assert @m.valid?
      assert_equal to, @m.permalink
    end
  end
  
  def test_multiple_attribute_permalink
    @m = MockModelExtra.new
    @@samples.each do |from, to|
      @@extra.each do |from_extra, to_extra|
        @m.title = from; @m.extra = from_extra; @m.permalink = nil
        assert @m.valid?
        assert_equal "#{to}-#{to_extra}", @m.permalink
      end
    end
  end

  def test_should_create_unique_permalink
    @m = MockModel.new
    @m.title = 'foo'
    assert @m.valid?
    assert_equal 'foo-2', @m.permalink
    
    @m.title = 'bar'
    @m.permalink = nil
    assert @m.valid?
    assert_equal 'bar-3', @m.permalink
  end
  
  def test_should_create_unique_permalink_when_assigned_directly
    @m = MockModel.new
    @m.permalink = 'foo'
    assert @m.valid?
    assert_equal 'foo-2', @m.permalink
    
    # should always check itself for uniqueness when not respond_to?(:permalink_changed?)
    @m.permalink = 'bar'
    assert @m.valid?
    assert_equal 'bar-3', @m.permalink
  end
  
  def test_should_common_permalink_if_unique_is_false
    @m = CommonMockModel.new
    @m.permalink = 'foo'
    assert @m.valid?
    assert_equal 'foo', @m.permalink
  end
  
  def test_should_not_check_itself_for_unique_permalink_if_unchanged
    @m = MockModel.new
    @m.id = 2
    @m.permalink = 'bar-2'
    @m.instance_eval do
      @changed_attributes = {}
    end
    assert @m.valid?
    assert_equal 'bar-2', @m.permalink
  end

  def test_should_check_itself_for_unique_permalink_if_permalink_field_changed
    @m = PermalinkChangeableMockModel.new
    @m.permalink_will_change!
    @m.permalink = 'foo'
    assert @m.valid?
    assert_equal 'foo-2', @m.permalink
  end

  def test_should_not_check_itself_for_unique_permalink_if_permalink_field_not_changed
    @m = PermalinkChangeableMockModel.new
    @m.permalink = 'foo'
    assert @m.valid?
    assert_equal 'foo', @m.permalink
  end
  
  def test_should_create_unique_scoped_permalink
    @m = ScopedModel.new
    @m.permalink = 'foo'
    assert @m.valid?
    assert_equal 'foo-2', @m.permalink
  
    @m.foo = 5
    @m.permalink = 'foo'
    assert @m.valid?
    assert_equal 'foo', @m.permalink
  end
  
  def test_should_limit_permalink
    @old = MockModel.columns_hash['permalink'].instance_variable_get(:@limit)
    MockModel.columns_hash['permalink'].instance_variable_set(:@limit, 2)
    @m   = MockModel.new
    @m.title = 'BOO'
    assert @m.valid?
    assert_equal 'bo', @m.permalink
  ensure
    MockModel.columns_hash['permalink'].instance_variable_set(:@limit, @old)
  end
  
  def test_should_limit_unique_permalink
    @old = MockModel.columns_hash['permalink'].instance_variable_get(:@limit)
    MockModel.columns_hash['permalink'].instance_variable_set(:@limit, 3)
    @m   = MockModel.new
    @m.title = 'foo'
    assert @m.valid?
    assert_equal 'f-2', @m.permalink
  ensure
    MockModel.columns_hash['permalink'].instance_variable_set(:@limit, @old)
  end
  
  def test_should_abide_by_if_proc_condition
    @m = IfProcConditionModel.new
    @m.title = 'dont make me a permalink'
    assert @m.valid?
    assert_nil @m.permalink
  end
  
  def test_should_abide_by_if_method_condition
    @m = IfMethodConditionModel.new
    @m.title = 'dont make me a permalink'
    assert @m.valid?
    assert_nil @m.permalink
  end
  
  def test_should_abide_by_if_string_condition
    @m = IfStringConditionModel.new
    @m.title = 'dont make me a permalink'
    assert @m.valid?
    assert_nil @m.permalink
  end
  
  def test_should_abide_by_unless_proc_condition
    @m = UnlessProcConditionModel.new
    @m.title = 'make me a permalink'
    assert @m.valid?
    assert_not_nil @m.permalink
  end
  
  def test_should_abide_by_unless_method_condition
    @m = UnlessMethodConditionModel.new
    @m.title = 'make me a permalink'
    assert @m.valid?
    assert_not_nil @m.permalink
  end
  
  def test_should_abide_by_unless_string_condition
    @m = UnlessStringConditionModel.new
    @m.title = 'make me a permalink'
    assert @m.valid?
    assert_not_nil @m.permalink
  end
  
  def test_should_allow_override_of_permalink_method
    @m = OverrideModel.new
    @m.write_attribute(:permalink, 'the permalink')
    assert_not_equal @m.permalink, @m.read_attribute(:permalink)
  end
  
  def test_should_create_permalink_from_attribute_not_attribute_accessor
    @m = OverrideModel.new
    @m.title = 'the permalink'
    assert @m.valid?
    assert_equal 'the-permalink', @m.read_attribute(:permalink)
  end
  
  def test_should_not_update_permalink_unless_field_changed
    @m = NoChangeModel.new
    @m.title = 'the permalink'
    @m.permalink = 'unchanged'
    assert @m.valid?
    assert_equal 'unchanged', @m.read_attribute(:permalink)
  end
  
  def test_should_not_update_permalink_without_update_set_even_if_field_changed
    @m = ChangedWithoutUpdateModel.new
    @m.title = 'the permalink'
    @m.permalink = 'unchanged'
    assert @m.valid?
    assert_equal 'unchanged', @m.read_attribute(:permalink)
  end
  
  def test_should_update_permalink_if_changed_method_does_not_exist
    @m = OverrideModel.new
    @m.title = 'the permalink'
    assert @m.valid?
    assert_equal 'the-permalink', @m.read_attribute(:permalink)
  end

  def test_should_update_permalink_if_the_existing_permalink_is_nil
    @m = NoChangeModel.new
    @m.title = 'the permalink'
    @m.permalink = nil
    assert @m.valid?
    assert_equal 'the-permalink', @m.read_attribute(:permalink)
  end

  def test_should_update_permalink_if_the_existing_permalink_is_blank
    @m = NoChangeModel.new
    @m.title = 'the permalink'
    @m.permalink = ''
    assert @m.valid?
    assert_equal 'the-permalink', @m.read_attribute(:permalink)
  end

  def test_should_assign_a_random_permalink_if_the_title_is_nil
    @m = NoChangeModel.new
    @m.title = nil
    assert @m.valid?
    assert_not_nil @m.read_attribute(:permalink)
    assert @m.read_attribute(:permalink).size > 0
  end

  def test_should_assign_a_random_permalink_if_the_title_has_no_permalinkable_characters
    @m = NoChangeModel.new
    @m.title = '////'
    assert @m.valid?
    assert_not_nil @m.read_attribute(:permalink)
    assert @m.read_attribute(:permalink).size > 0
  end

  def test_should_update_permalink_the_first_time_the_title_is_set
    @m = ChangedWithoutUpdateModel.new
    @m.title = "old title"
    assert @m.valid?
    assert_equal "old-title", @m.read_attribute(:permalink)
    @m.title = "new title"
    assert @m.valid?
    assert_equal "old-title", @m.read_attribute(:permalink)
  end

  def test_should_not_update_permalink_if_already_set_even_if_title_changed
    @m = ChangedWithoutUpdateModel.new
    @m.permalink = "old permalink"
    @m.title = "new title"
    assert @m.valid?
    assert_equal "old-permalink", @m.read_attribute(:permalink)
  end

  def test_should_update_permalink_every_time_the_title_is_changed
    @m = ChangedWithUpdateModel.new
    @m.title = "old title"
    assert @m.valid?
    assert_equal "old-title", @m.read_attribute(:permalink)
    @m.title = "new title"
    assert @m.valid?
    assert_equal "new-title", @m.read_attribute(:permalink)
  end
  
  def test_should_work_correctly_for_scoped_fields_with_nil_value
    s1 = ScopedModelForNilScope.new
    s1.title = 'ack'
    s1.foo = 3
    assert s1.valid?
    assert_equal 'ack', s1.permalink
    
    s2 = ScopedModelForNilScope.new
    s2.title = 'ack'
    s2.foo = nil
    assert s2.valid?
    assert_equal 'ack-2', s2.permalink
  end
end
