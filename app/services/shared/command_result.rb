# frozen_string_literal: true

# Shared result object for command operations
# Provides consistent success/failure handling across all commands
module Shared
  class CommandResult
    attr_reader :success, :data, :errors, :message

    def initialize(success:, data: nil, errors: [], message: nil)
      @success = success
      @data = data
      @errors = Array(errors)
      @message = message
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def self.success(data: nil, message: nil)
      new(success: true, data: data, message: message)
    end

    def self.failure(errors: [], message: nil)
      new(success: false, errors: errors, message: message)
    end
  end
end