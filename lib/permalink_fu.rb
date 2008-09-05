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

    # This method does the actual permalink escaping.
    def escape(str)
      s = ((translation_to && translation_from) ? Iconv.iconv(translation_to, translation_from, str) : str).to_s
      s.gsub!(/[^\w -]+/, '') # strip unwanted characters
      s.strip!                # ohh la la
      s.downcase!             #
      s.gsub!(/[ -]+/, '-')   # separate by single dashes
      s
    end
  end
  
  def self.included(base)
    base.extend PluginMethods
  end

  # This is the plugin method available on all ActiveRecord models.
  module PluginMethods
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
    #
    #     # do not bother checking for a unique scope
    #     has_permalink :title, :unique => false
    #   end
    #
    def has_permalink(attr_names = [], permalink_field = nil, options = {})
      if permalink_field.is_a?(Hash)
        options = permalink_field
        permalink_field = nil
      end
      extend ClassMethods
      self.permalink_attributes = Array(attr_names)
      self.permalink_field      = (permalink_field || 'permalink').to_s
      self.permalink_options    = {:unique => true}.update(options)
      setup_permalink_fu
    end
  end

  # Contains class methods for ActiveRecord models that have permalinks
  module ClassMethods
    def self.extended(base)
      class << base
        attr_accessor :permalink_options
        attr_accessor :permalink_attributes
        attr_accessor :permalink_field
      end
      base.send :include, InstanceMethods
    end

    def setup_permalink_fu
      if permalink_options[:unique]
        before_validation :create_unique_permalink
      else
        before_validation :create_common_permalink
      end
      class << self
        alias_method :define_attribute_methods_without_permalinks, :define_attribute_methods
        alias_method :define_attribute_methods, :define_attribute_methods_with_permalinks
      end
    end

    def define_attribute_methods_with_permalinks
      if value = define_attribute_methods_without_permalinks
        evaluate_attribute_method permalink_field, "def #{self.permalink_field}=(new_value);write_attribute(:#{self.permalink_field}, PermalinkFu.escape(new_value));end", "#{self.permalink_field}="
      end
      value
    end
  end

  # This contains instance methods for ActiveRecord models that have permalinks.
  module InstanceMethods
  protected
    def create_common_permalink
      return unless should_create_permalink?
      if read_attribute(self.class.permalink_field).to_s.empty?
        send("#{self.class.permalink_field}=", create_permalink_for(self.class.permalink_attributes))
      end
      limit   = self.class.columns_hash[self.class.permalink_field].limit
      base    = send("#{self.class.permalink_field}=", read_attribute(self.class.permalink_field)[0..limit - 1])
      [limit, base]
    end

    def create_unique_permalink
      limit, base = create_common_permalink
      return if limit.nil?
      counter = 1
      # oh how i wish i could use a hash for conditions
      conditions = ["#{self.class.permalink_field} = ?", base]
      unless new_record?
        conditions.first << " and id != ?"
        conditions       << id
      end
      if self.class.permalink_options[:scope]
        scopes = [self.class.permalink_options[:scope]]
        scopes.flatten!
        scopes.each do |scope|
          conditions.first << " and #{scope} = ?"
          conditions       << send(scope)
        end
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
end

if Object.const_defined?(:Iconv)
  PermalinkFu.translation_to   = 'ascii//translit//IGNORE'
  PermalinkFu.translation_from = 'utf-8'
end