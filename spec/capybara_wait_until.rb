require "timeout"

module Capybara
  class Session
    ##
    #
    # Retry executing the block until a truthy result is returned or the timeout time is exceeded
    # @param [Integer] timeout_limit - The amount of seconds to retry executing the given block
    # this method was removed in Capybara v2 so adding it back if not already defined
    #
    unless defined?(wait_until)
      # this implementation didnt work..
      #def wait_until(timeout_limit = Capybara.default_wait_time)
      #  Capybara.send(:timeout, timeout, driver) { yield }
      #end

      def wait_until(timeout_limit=Capybara.default_wait_time)
        Timeout.timeout(timeout_limit) do
          sleep(0.1) until value = yield
          value
        end
      end
    end
  end
end
