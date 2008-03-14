begin
  require 'iconv'
rescue Object
  puts "no iconv, you might want to look into it."
end

require 'digest/sha1'
module PermalinkFu
  class << self
    attr_accessor :translation_to
    attr_accessor :translation_from
    
    def escape(str)
      s = ((translation_to && translation_from) ? Iconv.iconv(translation_to, translation_from, str) : str).to_s
      s.gsub!(/\W+/, ' ') # all non-word chars to spaces
      s.strip!            # ohh la la
      s.downcase!         #
      s.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
      s
    end
  end
  
  def self.included(base)
    base.extend ClassMethods
    class << base
      attr_accessor :permalink_options
      attr_accessor :permalink_attributes
      attr_accessor :permalink_field
    end
  end
  
  module ClassMethods
    # Specifies the given field(s) as a permalink, meaning it is passed through PermalinkFu.escape and set to the permalink_field.  This
    # is done
    #
    #   class Foo < ActiveRecord::Base
    #     # stores permalink form of #title to the #permalink attribute
    #     has_permalink :title
    #   
    #     # stores a permalink form of "#{category}-#{title}" to the #permalink attribute
    #   
    #     has_permalink [:category, :title]
    #   
    #     # stores permalink form of #title to the #category_permalink attribute
    #     has_permalink [:category, :title], :category_permalink
    #
    #     # add a scope
    #     has_permalink :title, :scope => :blog_id
    #
    #     # add a scope and specify the permalink field name
    #     has_permalink :title, :slug, :scope => :blog_id
    #   end
    #
    def has_permalink(attr_names = [], permalink_field = nil, options = {})
      if permalink_field.is_a?(Hash)
        options = permalink_field
        permalink_field = nil
      end
      self.permalink_attributes = Array(attr_names)
      self.permalink_field      = (permalink_field || 'permalink').to_s
      self.permalink_options    = options
      before_validation :create_unique_permalink
      evaluate_attribute_method permalink_field, "def #{self.permalink_field}=(new_value);write_attribute(:#{self.permalink_field}, PermalinkFu.escape(new_value));end", "#{self.permalink_field}="
    end
  end
  
protected
  def create_unique_permalink
    return unless should_create_permalink?
    if send(self.class.permalink_field).to_s.empty?
      send("#{self.class.permalink_field}=", create_permalink_for(self.class.permalink_attributes))
    end
    limit   = self.class.columns_hash[self.class.permalink_field].limit
    base    = send("#{self.class.permalink_field}=", send(self.class.permalink_field)[0..limit - 1])
    counter = 1
    # oh how i wish i could use a hash for conditions
    conditions = ["#{self.class.permalink_field} = ?", base]
    unless new_record?
      conditions.first << " and id != ?"
      conditions       << id
    end
    if self.class.permalink_options[:scope]
      conditions.first << " and #{self.class.permalink_options[:scope]} = ?"
      conditions       << send(self.class.permalink_options[:scope])
    end
    while self.class.exists?(conditions)
      suffix = "-#{counter += 1}"
      conditions[1] = "#{base[0..limit-suffix.size-1]}#{suffix}"
      send("#{self.class.permalink_field}=", conditions[1])
    end
  end

  def create_permalink_for(attr_names)
    attr_names.collect { |attr_name| send(attr_name).to_s } * " "
  end

private
  def should_create_permalink?
    if self.class.permalink_options[:if]
      evaluate_method(self.class.permalink_options[:if])
    elsif self.class.permalink_options[:unless]
      !evaluate_method(self.class.permalink_options[:unless])
    else
      true
    end
  end

  def evaluate_method(method)
    case method
    when Symbol
      send(method)
    when String
      eval(method, instance_eval { binding })
    when Proc, Method
      method.call(self)
    end
  end
end

if Object.const_defined?(:Iconv)
  PermalinkFu.translation_to   = 'ascii//translit//IGNORE'
  PermalinkFu.translation_from = 'utf-8'
end