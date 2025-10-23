# frozen_string_literal: true

# Controller layer authorization protection for ActiveAdmin resources
# Provides unified permission checking and error handling for API security
module AuthorizationConcern
  extend ActiveSupport::Concern

  included do
    before_action :check_current_user
    rescue_from StandardError, with: :handle_authorization_error
  end

  class_methods do
    # Define permission checks for different actions
    #
    # Usage:
    #   protect_action :index, with: :ReimbursementPolicy, method: :can_index?
    #   protect_action :create, with: :ReimbursementPolicy, method: :can_create?
    #   protect_action :batch_action, with: :ReimbursementPolicy, method: :can_batch_assign?
    #   protect_action :member_action, action_name: :assign, with: :ReimbursementPolicy, method: :can_assign?
    #
    def protect_action(action_type, options = {})
      case action_type
      when :member_action
        protect_member_action(options[:action_name], options)
      when :batch_action
        protect_batch_action(options[:action_name] || action_type, options)
      when :collection_action
        protect_collection_action(options[:action_name] || action_type, options)
      else
        protect_standard_action(action_type, options)
      end
    end

    private

    def protect_member_action(action_name, options)
      policy_class = options[:with]
      method_name = options[:method] || "can_#{action_name}?"

      before_action only: [action_name] do
        instance_eval(&member_action_permission_check(policy_class, method_name))
      end
    end

    def protect_batch_action(action_name, options)
      policy_class = options[:with]
      method_name = options[:method] || "can_#{action_name}?"

      before_action only: [action_name] do
        instance_eval(&batch_action_permission_check(policy_class, method_name))
      end
    end

    def protect_collection_action(action_name, options)
      policy_class = options[:with]
      method_name = options[:method] || "can_#{action_name}?"

      before_action only: [action_name] do
        instance_eval(&collection_action_permission_check(policy_class, method_name))
      end
    end

    def protect_standard_action(action_name, options)
      policy_class = options[:with]
      method_name = options[:method] || "can_#{action_name}?"
      resource = options[:resource]

      before_action only: [action_name] do
        instance_eval(&standard_action_permission_check(policy_class, method_name, resource))
      end
    end

    def member_action_permission_check(policy_class, method_name)
      lambda do
        policy = policy_class.constantize.new(current_admin_user, resource)
        check_authorization(policy, method_name, member_action: params[:action])
      end
    end

    def batch_action_permission_check(policy_class, method_name)
      lambda do
        policy = policy_class.constantize.new(current_admin_user)
        check_authorization(policy, method_name, batch_action: params[:batch_action])
      end
    end

    def collection_action_permission_check(policy_class, method_name)
      lambda do
        policy = policy_class.constantize.new(current_admin_user)
        check_authorization(policy, method_name, collection_action: params[:action])
      end
    end

    def standard_action_permission_check(policy_class, method_name, resource_name)
      lambda do
        target_resource = resource_name ? controller_name.classify.constantize : resource
        policy = policy_class.constantize.new(current_admin_user, target_resource)
        check_authorization(policy, method_name, standard_action: action_name)
      end
    end
  end

  private

  # Ensure user is authenticated
  def check_current_user
    unless current_admin_user.present?
      handle_authentication_error
      return false
    end
  end

  # Core authorization check method
  def check_authorization(policy, permission_method, options = {})
    # Check if user exists
    unless current_admin_user.present?
      log_authorization_failure('User not authenticated', options)
      handle_authentication_error
      return false
    end

    # Check if policy method exists
    unless policy.respond_to?(permission_method)
      log_authorization_failure("Permission method #{permission_method} not found", options)
      handle_authorization_error("权限检查配置错误", :internal_error)
      return false
    end

    # Execute permission check
    authorized = policy.send(permission_method)

    unless authorized
      error_message = policy.respond_to?(:authorization_error_message) ?
                     policy.authorization_error_message(action: extract_action_from_options(options)) :
                     '您没有权限执行此操作'

      log_authorization_failure(error_message, options)
      handle_authorization_error(error_message, options)
      return false
    end

    # Log successful authorization
    log_authorization_success(options)
    true
  end

  # Handle authentication errors
  def handle_authentication_error
    respond_to do |format|
      format.html {
        flash[:alert] = '请先登录'
        redirect_to new_admin_user_session_path
      }
      format.json {
        render json: {
          error: 'Authentication required',
          message: '请先登录',
          code: 401
        }, status: :unauthorized
      }
    end
  end

  # Handle authorization errors
  def handle_authorization_error(message, options = {})
    respond_to do |format|
      format.html {
        redirect_path = options[:redirect_to] ||
                       (respond_to?(:collection_path) ? collection_path : admin_dashboard_path)
        redirect_to redirect_path, alert: message
      }
      format.json {
        render json: {
          error: 'Authorization failed',
          message: message,
          code: 403,
          action: extract_action_from_options(options)
        }, status: :forbidden
      }
    end
  end

  # Handle unexpected errors
  def handle_authorization_error(exception)
    Rails.logger.error "Authorization error: #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if Rails.env.development?

    respond_to do |format|
      format.html {
        flash[:alert] = '系统发生错误，请稍后重试'
        redirect_to admin_dashboard_path
      }
      format.json {
        render json: {
          error: 'Internal server error',
          message: '系统发生错误，请稍后重试',
          code: 500
        }, status: :internal_server_error
      }
    end
  end

  # Extract action name for logging and error messages
  def extract_action_from_options(options)
    options[:member_action] ||
    options[:batch_action] ||
    options[:collection_action] ||
    options[:standard_action] ||
    action_name
  end

  # Log successful authorization
  def log_authorization_success(options)
    return unless Rails.env.production? || Rails.env.staging?

    action = extract_action_from_options(options)
    controller_name = self.class.name.gsub('Controller', '')

    Rails.logger.info "[AUTH_SUCCESS] User: #{current_admin_user.email} | " \
                      "Controller: #{controller_name} | Action: #{action} | " \
                      "IP: #{request.remote_ip} | " \
                      "User-Agent: #{request.user_agent}"
  end

  # Log authorization failure
  def log_authorization_failure(reason, options)
    action = extract_action_from_options(options)
    controller_name = self.class.name.gsub('Controller', '')

    Rails.logger.warn "[AUTH_FAILURE] User: #{current_admin_user&.email || 'Unknown'} | " \
                      "Controller: #{controller_name} | Action: #{action} | " \
                      "Reason: #{reason} | " \
                      "IP: #{request.remote_ip} | " \
                      "User-Agent: #{request.user_agent}"

    # Also log to security audit log
    log_security_alert(action, reason)
  end

  # Log security alerts for audit purposes
  def log_security_alert(action, reason)
    security_log = {
      timestamp: Time.current.iso8601,
      event_type: 'authorization_failure',
      user_id: current_admin_user&.id,
      user_email: current_admin_user&.email,
      user_role: current_admin_user&.role,
      controller: controller_name,
      action: action,
      reason: reason,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_params: sanitize_params_for_logging
    }

    # Write to separate security log file if configured
    Rails.logger.info "[SECURITY_ALERT] #{security_log.to_json}"
  end

  # Sanitize sensitive parameters for logging
  def sanitize_params_for_logging
    return {} unless params.respond_to?(:to_unsafe_h)

    safe_params = params.to_unsafe_h.dup
    sensitive_keys = %w[password password_confirmation current_password file file]

    safe_params.each do |key, value|
      if sensitive_keys.include?(key.to_s)
        safe_params[key] = '[FILTERED]'
      elsif value.is_a?(Hash)
        value.each do |sub_key, sub_value|
          if sensitive_keys.include?(sub_key.to_s)
            safe_params[key][sub_key] = '[FILTERED]'
          end
        end
      end
    end

    safe_params
  end

  # Helper methods for common permission patterns
  def require_super_admin!
    unless current_admin_user&.super_admin?
      handle_authorization_error('此操作仅限超级管理员执行', { redirect_to: admin_dashboard_path })
      return false
    end
    true
  end

  def require_admin_or_super_admin!
    unless current_admin_user&.admin? || current_admin_user&.super_admin?
      handle_authorization_error('此操作仅限管理员执行', { redirect_to: admin_dashboard_path })
      return false
    end
    true
  end

  def require_permission?(policy_class, method_name, resource = nil)
    policy = policy_class.constantize.new(current_admin_user, resource)
    policy.send(method_name)
  end

  # Double permission check for sensitive operations
  def verify_sensitive_operation(policy_class, resource, operation)
    return false unless check_current_user

    # First permission check
    primary_method = "can_#{operation}?"
    return false unless require_permission?(policy_class, primary_method, resource)

    # Secondary verification for most sensitive operations
    sensitive_operations = %w[destroy delete batch_delete restore change_role]
    if sensitive_operations.include?(operation.to_s)
      log_sensitive_operation_attempt(operation, resource)
    end

    true
  end

  # Log attempts at sensitive operations
  def log_sensitive_operation_attempt(operation, resource)
    Rails.logger.warn "[SENSITIVE_OPERATION] User: #{current_admin_user.email} | " \
                      "Operation: #{operation} | " \
                      "Resource: #{resource.class.name}##{resource.try(:id)} | " \
                      "IP: #{request.remote_ip} | " \
                      "Timestamp: #{Time.current.iso8601}"
  end
end