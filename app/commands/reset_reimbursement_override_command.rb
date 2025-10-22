# frozen_string_literal: true

require_relative '../services/shared/command_result'
require_relative '../repositories/reimbursement_repository'

# Command for resetting manual status override for reimbursements
# Encapsulates the business logic and validation for override reset operations
module Commands
  class ResetReimbursementOverrideCommand
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :reimbursement_id, :current_user
    validates :reimbursement_id, :current_user, presence: true

    def initialize(reimbursement_id: nil, current_user: nil)
      @reimbursement_id = reimbursement_id
      @current_user = current_user
    end

    def call
      return failure_result(errors.full_messages) unless valid?

      # Get the reimbursement
      reimbursement = find_reimbursement
      return failure_result(["Reimbursement not found"]) unless reimbursement

      # Perform the override reset
      result = perform_override_reset(reimbursement)

      if result.success?
        success_result(result.reimbursement)
      else
        failure_result([result.message])
      end
    rescue => e
      failure_result(["Unexpected error: #{e.message}"])
    end

    private

    def find_reimbursement
      ReimbursementRepository.find(@reimbursement_id)
    end

    def perform_override_reset(reimbursement)
      service = ReimbursementStatusOverrideService.new(@current_user)
      service.reset_override(reimbursement)
    end

    def success_result(data)
      Shared::CommandResult.success(
        data: data,
        message: "Successfully reset manual override for reimbursement"
      )
    end

    def failure_result(errors)
      Shared::CommandResult.failure(
        errors: errors,
        message: errors.join(", ")
      )
    end
  end
end