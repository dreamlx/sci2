# frozen_string_literal: true

require_relative '../services/shared/command_result'
require_relative '../repositories/reimbursement_repository'

# Command for setting reimbursement status with manual override
# Encapsulates the business logic and validation for manual status changes
module Commands
  class SetReimbursementStatusCommand
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :reimbursement_id, :status, :current_user

    validates :reimbursement_id, :status, :current_user, presence: true

    def initialize(reimbursement_id: nil, status: nil, current_user: nil)
      @reimbursement_id = reimbursement_id
      @status = status
      @current_user = current_user
    end

    def call
      return failure_result(errors.full_messages) unless valid?

      # Get the reimbursement
      reimbursement = find_reimbursement
      return failure_result(['Reimbursement not found']) unless reimbursement

      # Perform the status change
      result = perform_status_change(reimbursement)

      if result.success?
        success_result(result.reimbursement)
      else
        failure_result([result.message])
      end
    rescue StandardError => e
      failure_result(["Unexpected error: #{e.message}"])
    end

    private

    def find_reimbursement
      ReimbursementRepository.find(@reimbursement_id)
    end

    def perform_status_change(reimbursement)
      service = ReimbursementStatusOverrideService.new(@current_user)
      service.set_status(reimbursement, @status)
    end

    def success_result(data)
      Shared::CommandResult.success(
        data: data,
        message: "Successfully set reimbursement status to '#{@status}'"
      )
    end

    def failure_result(errors)
      Shared::CommandResult.failure(
        errors: errors,
        message: errors.join(', ')
      )
    end
  end
end
