# Service for handling manual status override operations for reimbursements
# Provides controlled methods to override reimbursement status with proper validation and audit trail
class ReimbursementStatusOverrideService
  # Result object for service operations
  class Result
    attr_reader :success, :message, :reimbursement, :errors

    def initialize(success:, message:, reimbursement: nil, errors: [])
      @success = success
      @message = message
      @reimbursement = reimbursement
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  def initialize(current_user = nil)
    @current_user = current_user
  end

  # Manually set reimbursement status with override
  # @param reimbursement [Reimbursement] The reimbursement to modify
  # @param status [String] The new status to set
  # @return [Result] Result object with success/failure information
  def set_status(reimbursement, status)
    # Validate inputs
    result = validate_set_status_inputs(reimbursement, status)
    return result unless result.success?

    # Check if status is actually changing
    if reimbursement.status == status
      return Result.new(
        success: false,
        message: "Status is already set to '#{status}'. No change needed.",
        reimbursement: reimbursement
      )
    end

    begin
      # Store previous status for audit
      previous_status = reimbursement.status

      # Perform the manual status change (includes logging)
      reimbursement.manual_status_change!(status, @current_user)

      Result.new(
        success: true,
        message: "Successfully updated reimbursement #{reimbursement.invoice_number} status from '#{previous_status}' to '#{status}' with manual override.",
        reimbursement: reimbursement
      )
    rescue ActiveRecord::RecordInvalid => e
      Result.new(
        success: false,
        message: "Failed to update status: #{e.message}",
        reimbursement: reimbursement,
        errors: e.record.errors.full_messages
      )
    rescue StandardError => e
      Result.new(
        success: false,
        message: "Unexpected error occurred: #{e.message}",
        reimbursement: reimbursement,
        errors: [e.message]
      )
    end
  end

  # Reset manual override for a reimbursement
  # @param reimbursement [Reimbursement] The reimbursement to reset
  # @return [Result] Result object with success/failure information
  def reset_override(reimbursement)
    # Validate inputs
    result = validate_reset_inputs(reimbursement)
    return result unless result.success?

    # Check if there's actually an override to reset
    unless reimbursement.manual_override?
      return Result.new(
        success: false,
        message: "No manual override exists for reimbursement #{reimbursement.invoice_number}.",
        reimbursement: reimbursement
      )
    end

    begin
      # Reset the manual override
      reimbursement.reset_manual_override!

      # Log the reset operation
      log_override_reset(reimbursement)

      Result.new(
        success: true,
        message: "Successfully reset manual override for reimbursement #{reimbursement.invoice_number}.",
        reimbursement: reimbursement
      )
    rescue ActiveRecord::RecordInvalid => e
      Result.new(
        success: false,
        message: "Failed to reset override: #{e.message}",
        reimbursement: reimbursement,
        errors: e.record.errors.full_messages
      )
    rescue StandardError => e
      Result.new(
        success: false,
        message: "Unexpected error occurred: #{e.message}",
        reimbursement: reimbursement,
        errors: [e.message]
      )
    end
  end

  private

  attr_reader :current_user

  # Validate inputs for set_status operation
  def validate_set_status_inputs(reimbursement, status)
    unless reimbursement.is_a?(Reimbursement)
      return Result.new(
        success: false,
        message: "Invalid reimbursement object provided."
      )
    end

    unless status.is_a?(String) && status.present?
      return Result.new(
        success: false,
        message: "Invalid status provided. Status must be a non-empty string."
      )
    end

    unless Reimbursement::STATUSES.include?(status)
      return Result.new(
        success: false,
        message: "Invalid status '#{status}'. Valid statuses are: #{Reimbursement::STATUSES.join(', ')}."
      )
    end

    Result.new(success: true, message: "Inputs validated successfully.")
  end

  # Validate inputs for reset_override operation
  def validate_reset_inputs(reimbursement)
    unless reimbursement.is_a?(Reimbursement)
      return Result.new(
        success: false,
        message: "Invalid reimbursement object provided."
      )
    end

    Result.new(success: true, message: "Inputs validated successfully.")
  end

  # Log override reset operation
  def log_override_reset(reimbursement)
    user_info = @current_user ? "by #{@current_user.email}" : "by system"
    Rails.logger.info(
      "Manual override reset #{user_info}: " \
      "Reimbursement #{reimbursement.invoice_number} " \
      "at #{Time.current}"
    )
  end

  end