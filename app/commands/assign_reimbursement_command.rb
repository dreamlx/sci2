# frozen_string_literal: true

require_relative '../services/shared/command_result'
require_relative '../repositories/reimbursement_repository'

# Command for assigning a reimbursement to a user
# Encapsulates the business logic and validation for reimbursement assignment
module Commands
  class AssignReimbursementCommand
    include ActiveModel::Model
    include ActiveModel::Attributes

    attr_accessor :reimbursement_id, :assignee_id, :notes, :current_user
    validates :reimbursement_id, :assignee_id, :current_user, presence: true

    def initialize(reimbursement_id: nil, assignee_id: nil, notes: nil, current_user: nil)
      @reimbursement_id = reimbursement_id
      @assignee_id = assignee_id
      @notes = notes
      @current_user = current_user
    end

    def call
      return failure_result(errors.full_messages) unless valid?

      # Get the reimbursement
      reimbursement = find_reimbursement
      return failure_result(["Reimbursement not found"]) unless reimbursement

      # Get the assignee
      assignee = find_assignee
      return failure_result(["Assignee not found"]) unless assignee

      # Perform the assignment
      assignment = perform_assignment(reimbursement, assignee)

      if assignment
        success_result(assignment)
      else
        failure_result(["Assignment failed"])
      end
    rescue => e
      failure_result(["Unexpected error: #{e.message}"])
    end

    private

    def find_reimbursement
      ReimbursementRepository.find(@reimbursement_id)
    end

    def find_assignee
      AdminUser.find(@assignee_id)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def perform_assignment(reimbursement, assignee)
      service = ReimbursementAssignmentService.new(@current_user)
      service.assign(reimbursement.id, assignee.id, @notes)
    end

    def success_result(data)
      Shared::CommandResult.success(data: data, message: "Successfully assigned reimbursement")
    end

    def failure_result(errors)
      Shared::CommandResult.failure(errors: errors, message: errors.join(", "))
    end
  end
end