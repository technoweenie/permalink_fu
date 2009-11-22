require 'test/unit'
require File.join(File.dirname(__FILE__), '../lib/permalink_fu')

begin
  require 'rubygems'
  require 'ruby-debug'
  Debugger.start
rescue LoadError
  # no ruby debugger
end

gem 'activerecord'
require 'active_record'
require File.join(File.dirname(__FILE__), '../init')

class BaseModel < ActiveRecord::Base
  cattr_accessor :columns
  @@columns ||= []
  
  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type, null)
  end
  
  def self.exists?(*args)
    false
  end
  
  column :id,         'int(11)'
  column :title,      'varchar(100)'
  column :permalink,  'varchar(100)'
  column :extra,      'varchar(100)'
  column :foo,        'varchar(100)'
  
end

class ClassModel < BaseModel
  has_permalink :title
end

class SubClassHasPermalinkModel < ClassModel
  has_permalink [:title, :extra]
end

class SubClassNoPermalinkModel < ClassModel
end

class MockModel < BaseModel
  def self.exists?(conditions)
    if conditions[1] == 'foo'   || conditions[1] == 'bar' || 
      (conditions[1] == 'bar-2' && conditions[2] != 2)
      true
    else
      false
    end
  end

  has_permalink :title
end

class PermalinkChangeableMockModel < BaseModel
  def self.exists?(conditions)
    if conditions[1] == 'foo'
      true
    else
      false
    end
  end

  has_permalink :title

  def permalink_changed?
    @permalink_changed
  end

  def permalink_will_change!
    @permalink_changed = true
  end
end

class CommonMockModel < BaseModel
  def self.exists?(conditions)
    false # oh noes
  end

  has_permalink :title, :unique => false
end

class ScopedModel < BaseModel
  def self.exists?(conditions)
    if conditions[1] == 'foo' && conditions[2] != 5
      true
    else
      false
    end
  end

  has_permalink :title, :scope => :foo
end

class ScopedModelForNilScope < BaseModel
  def self.exists?(conditions)
    (conditions[0] == 'permalink = ? and foo IS NULL') ? (conditions[1] == 'ack') : false
  end

  has_permalink :title, :scope => :foo
end

class OverrideModel < BaseModel
  has_permalink :title
  
  def permalink
    'not the permalink'
  end
end

class ChangedWithoutUpdateModel < BaseModel
  has_permalink :title  
  def title_changed?; true; end
end

class ChangedWithUpdateModel < BaseModel
  has_permalink :title, :update => true 
  def title_changed?; true; end
end

class NoChangeModel < BaseModel
  has_permalink :title, :update => true
  def title_changed?; false; end
end

class IfProcConditionModel < BaseModel
  has_permalink :title, :if => Proc.new { |obj| false }
end

class IfMethodConditionModel < BaseModel
  has_permalink :title, :if => :false_method
  
  def false_method; false; end
end

class IfStringConditionModel < BaseModel
  has_permalink :title, :if => 'false'
end

class UnlessProcConditionModel < BaseModel
  has_permalink :title, :unless => Proc.new { |obj| false }
end

class UnlessMethodConditionModel < BaseModel
  has_permalink :title, :unless => :false_method
  
  def false_method; false; end
end

class UnlessStringConditionModel < BaseModel
  has_permalink :title, :unless => 'false'
end

class MockModelExtra < BaseModel
  has_permalink [:title, :extra]
end

