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
  # end
  #
  def has_permalink(attr_names = [], permalink_field = nil)
    permalink_field ||= 'permalink'
    before_validation { |record| record.send("#{permalink_field}=", Array(attr_names).collect { |attr_name| PermalinkFu.escape(record.send(attr_name).to_s) }.join('-')) if record.send(permalink_field).to_s.empty? }
  end
end

PermalinkFu.translation_to   = 'ascii//ignore//translit'
PermalinkFu.translation_from = 'utf-8'
