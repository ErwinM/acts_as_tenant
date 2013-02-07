# Shamelessly borrowed from CanCan

module ActsAsTenant
  # A general ActsAsTenant exception
  class Error < StandardError; end

  # Raised when behavior is not implemented, usually used in an abstract class.
  class NotImplemented < Error; end

  # Raised when removed code is called, an alternative solution is provided in message.
  class ImplementationRemoved < Error; end

  class ScopeNotSet < Error
    attr_writer :default_message

    def initialize(message = nil, action = nil, subject = nil)
      #@message = message
      #@action = action
      #@subject = subject
      #@default_message = "No scope set."
    end

    def to_s
      #@message || @default_message
    end
  end
end
