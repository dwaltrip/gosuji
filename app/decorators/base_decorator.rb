# Example usage
#
#class MyDecorator < BaseDecorator
#    def new_method
#      "new_method"
#    end
#    def foo
#       "Overridden #{super}"
#    end
#    def a_rails_helper
#      _h.tag("br")
#    end
#end

require 'delegate'

class BaseDecorator < SimpleDelegator
  def initialize(base, view_context=nil)
    super(base)
    @view_context = view_context if view_context
  end

  def _h
    @view_context || nil
  end

  def html_escape(*args)
    ERB::Util.html_escape(*args)
  end
end

