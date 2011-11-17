module Ayl

  #
  # A logger to use to limit the amount of junk output while the test is running
  #
  class NullLogger

    Ayl::Logger::LOG_METHODS.each do | method |
      define_method(method) do |message|
        # Do nothing
      end
    end

  end

end
