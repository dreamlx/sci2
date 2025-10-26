# frozen_string_literal: true

# WorkOrderStatusTraits - 工单状态特性模块
# 为不同类型的工单提供统一但智能的状态管理
module WorkOrderStatusTraits
  extend ActiveSupport::Concern

  included do
    # 类属性定义状态特性，支持子类继承和覆盖
    class_attribute :status_traits, default: {}
  end

  class_methods do
    # 定义状态特性
    # @param traits [Hash] 状态特性配置
    # @option traits [Array<String>] :available_statuses 可用状态列表
    # @option traits [String] :initial_status 初始状态
    # @option traits [Array<String>] :final_statuses 最终状态列表
    # @option traits [Boolean] :always_completed 是否总是完成状态
    # @option traits [Boolean] :auto_completed 是否自动完成
    # @option traits [Boolean] :manual_status_only 是否只能手动设置状态
    def define_status_traits(traits)
      self.status_traits = default_traits.merge(traits)
    end

    # 默认状态特性
    def default_traits
      {
        available_statuses: %w[pending processing approved rejected completed],
        initial_status: 'pending',
        final_statuses: %w[approved rejected completed],
        always_completed: false,
        auto_completed: false,
        manual_status_only: false
      }
    end

    # 状态特性查询方法

    # 是否总是完成状态（如ExpressReceiptWorkOrder）
    def always_completed?
      status_traits[:always_completed] == true
    end

    # 是否自动完成（如CommunicationWorkOrder）
    def auto_completed?
      status_traits[:auto_completed] == true
    end

    # 是否只能手动设置状态（如AuditWorkOrder）
    def manual_status_only?
      status_traits[:manual_status_only] == true
    end

    # 获取可用状态列表
    def available_statuses
      status_traits[:available_statuses] || default_traits[:available_statuses]
    end

    # 获取初始状态
    def initial_status
      status_traits[:initial_status] || default_traits[:initial_status]
    end

    # 获取最终状态列表
    def final_statuses
      status_traits[:final_statuses] || default_traits[:final_statuses]
    end

    # 检查状态是否可用
    def status_available?(status)
      available_statuses.include?(status.to_s)
    end

    # 检查是否为最终状态
    def final_status?(status)
      final_statuses.include?(status.to_s)
    end

    # 获取状态转换规则
    def status_transitions
      {
        'pending' => ['processing', 'approved', 'rejected', 'completed'],
        'processing' => ['approved', 'rejected', 'completed'],
        'approved' => [],
        'rejected' => [],
        'completed' => []
      }
    end

    # 检查是否可以转换到目标状态
    def can_transition_from?(from_status, to_status)
      return false unless status_available?(to_status)
      return false if from_status.nil? || from_status.empty?

      transitions = status_transitions[from_status] || []
      transitions.include?(to_status)
    end
  end

  # 实例方法

  # 检查当前状态是否为最终状态
  def final_status?
    self.class.final_status?(status)
  end

  # 检查是否可以转换到目标状态
  def can_transition_to?(new_status)
    return false unless self.class.status_available?(new_status)
    return true if status.blank? # 初始状态可以转换到可用状态

    self.class.can_transition_from?(status, new_status)
  end

  # 获取下一个可能的状态列表
  def next_possible_statuses
    return self.class.available_statuses if status.blank?
    self.class.status_transitions[status] || []
  end

  # 状态转换（带验证）
  def transition_to!(new_status, options = {})
    unless can_transition_to?(new_status)
      raise ArgumentError, "无法从 #{status} 转换到 #{new_status}"
    end

    self.status = new_status
    save!
  end

  # 安全状态转换（不抛异常）
  def safe_transition_to(new_status, options = {})
    transition_to!(new_status, options)
  rescue ArgumentError => e
    errors.add(:status, e.message)
    false
  end
end