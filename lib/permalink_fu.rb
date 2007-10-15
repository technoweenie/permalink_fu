require 'iconv'
module PermalinkFu
  class << self
    attr_accessor :translation_to
    attr_accessor :translation_from
    
    def escape(str)
      s = Iconv.iconv(translation_to, translation_from, str).to_s
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
      attr_accessor :permalink_attributes
      attr_accessor :permalink_field
    end
  end
  
  module ClassMethods
    # Specifies the given field(s) as a permalink, meaning it is passed through PermalinkFu.escape and set to the permalink_field.  This
    # is done
    #
    # class Foo < ActiveRecord::Base
    #   # stores permalink form of #title to the #permalink attribute
    #   has_permalink :title
    #
    #   # stores a permalink form of "#{category}-#{title}" to the #permalink attribute
    #
    #   has_permalink [:category, :title]
    #
    #   # stores permalink form of #title to the #category_permalink attribute
    #   has_permalink [:category, :title], :category_permalink
    #
    #   
    # end
    #
    def has_permalink(attr_names = [], permalink_field = 'permalink')
      self.permalink_attributes = Array(attr_names)
      self.permalink_field      = permalink_field
      before_validation :create_unique_permalink
    end
  end
  
protected
  def create_unique_permalink
    if send(self.class.permalink_field).to_s.empty?
      send("#{self.class.permalink_field}=", create_permalink_for(self.class.permalink_attributes))
    end
    base       = send(self.class.permalink_field)
    counter    = 1
    conditions = ["#{self.class.permalink_field} = ?", send(self.class.permalink_field)]
    unless new_record?
      conditions.first << " and id != ?"
      conditions       << id
    end
    while self.class.count(:all, :conditions => conditions) > 0
      conditions[1] = "#{base}-#{counter += 1}"
      send("#{self.class.permalink_field}=", conditions[1])
    end
  end

  def create_permalink_for(attr_names)
    attr_names.collect do |attr_name| 
      PermalinkFu.escape(send(attr_name).to_s)
    end.join('-')
  end
end

PermalinkFu.translation_to   = 'ascii//ignore//translit'
PermalinkFu.translation_from = 'utf-8'
