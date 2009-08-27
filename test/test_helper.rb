require 'test/unit'
require File.join(File.dirname(__FILE__), '../lib/permalink_fu')

begin
  require 'rubygems'
  require 'ruby-debug'
  Debugger.start
rescue LoadError
  puts "no ruby debugger"
end

gem 'activesupport'
require 'active_support/core_ext/blank'

class FauxColumn < Struct.new(:limit)
end

class BaseModel
  def self.columns_hash
    @columns_hash ||= {'permalink' => FauxColumn.new(100)}
  end

  def self.inherited(base)
    subclasses << base
  end

  extend PermalinkFu::PluginMethods
  attr_accessor :id
  attr_accessor :title
  attr_accessor :extra
  attr_reader   :permalink
  attr_accessor :foo

  class << self
    attr_accessor :validation, :subclasses
  end
  self.subclasses = []

  def self.generated_methods
    @generated_methods ||= []
  end
  
  def self.primary_key
    :id
  end
  
  def self.logger
    nil
  end

  def self.define_attribute_methods
    return unless generated_methods.empty?
    true
  end

  # ripped from AR
  def self.evaluate_attribute_method(attr_name, method_definition, method_name=attr_name)

    unless method_name.to_s == primary_key.to_s
      generated_methods << method_name
    end

    begin
      class_eval(method_definition, __FILE__, __LINE__)
    rescue SyntaxError => err
      generated_methods.delete(attr_name)
      if logger
        logger.warn "Exception occurred during reader method compilation."
        logger.warn "Maybe #{attr_name} is not a valid Ruby identifier?"
        logger.warn "#{err.message}"
      end
    end
  end

  def self.exists?(*args)
    false
  end

  def self.before_validation(method)
    self.validation = method
  end

  def validate
    send self.class.validation if self.class.validation
    permalink
  end
  
  def new_record?
    @id.nil?
  end
  
  def write_attribute(key, value)
    instance_variable_set "@#{key}", value
  end
  
  def read_attribute(key)
    instance_variable_get "@#{key}"
  end
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

# trying to be like ActiveRecord, define the attribute methods manually
BaseModel.subclasses.each { |c| c.send :define_attribute_methods }

