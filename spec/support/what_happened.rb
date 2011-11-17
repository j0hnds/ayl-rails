class WhatHappened
  include Singleton
  attr_accessor :what_ran
  def <<(message) @what_ran ||= []; @what_ran << message end
  def clear() @what_ran = nil end
end

