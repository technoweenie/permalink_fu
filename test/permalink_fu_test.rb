require 'test/unit'
require File.join(File.dirname(__FILE__), '../lib/permalink_fu')

class MockModel
  extend PermalinkFu
  attr_accessor :title
  attr_accessor :permalink
  
  def self.before_validation(&block)
    @@validation = block
  end
  
  def validate
    @@validation.call self
    permalink
  end
  
  has_permalink :title
end

class MockModelExtra
  extend PermalinkFu
  attr_accessor :title
  attr_accessor :extra
  attr_accessor :permalink

  def self.before_validation(&block)
    @@validation = block
  end

  def validate
    @@validation.call self
    permalink
  end

  has_permalink [:title, :extra]
end

class PermalinkFuTest < Test::Unit::TestCase
  @@samples = {
    'This IS a Tripped out title!!.!1  (well/ not really)' => 'this-is-a-tripped-out-title-1-well-not-really',
    '////// meph1sto r0x ! \\\\\\' => 'meph1sto-r0x',
    'āčēģīķļņū' => 'acegiklnu'
  }

  @@extra = { 'some-)()()-ExtRa!/// .data==?>    to \/\/test' => 'some-extra-data-to-test' }

  def test_should_escape_permalinks
    @@samples.each do |from, to|
      assert_equal to, PermalinkFu.escape(from)
    end
  end
  
  def test_should_escape_activerecord_model
    @m = MockModel.new
    @@samples.each do |from, to|
      @m.title = from; @m.permalink = nil
      assert_equal to, @m.validate
    end
  end

  def test_multiple_attribute_permalink
    @m = MockModelExtra.new
    @@samples.each do |from, to|
      @@extra.each do |from_extra, to_extra|
        @m.title = from; @m.extra = from_extra; @m.permalink = nil
        assert_equal "#{to}-#{to_extra}", @m.validate
      end
    end
  end
end
