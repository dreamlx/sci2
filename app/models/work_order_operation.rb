class WorkOrderOperation < ApplicationRecord
  belongs_to :work_order
  belongs_to :admin_user
  
  validates :operation_type, presence: true
  
  scope :by_work_order, ->(work_order_id) { where(work_order_id: work_order_id) }
  scope :by_admin_user, ->(admin_user_id) { where(admin_user_id: admin_user_id) }
  scope :by_operation_type, ->(operation_type) { where(operation_type: operation_type) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  # 操作类型常量
  OPERATION_TYPE_CREATE = 'create'.freeze
  OPERATION_TYPE_UPDATE = 'update'.freeze
  OPERATION_TYPE_STATUS_CHANGE = 'status_change'.freeze
  OPERATION_TYPE_ADD_PROBLEM = 'add_problem'.freeze
  OPERATION_TYPE_REMOVE_PROBLEM = 'remove_problem'.freeze
  OPERATION_TYPE_MODIFY_PROBLEM = 'modify_problem'.freeze
  
  # 操作类型列表
  def self.operation_types
    [
      OPERATION_TYPE_CREATE,
      OPERATION_TYPE_UPDATE,
      OPERATION_TYPE_STATUS_CHANGE,
      OPERATION_TYPE_ADD_PROBLEM,
      OPERATION_TYPE_REMOVE_PROBLEM,
      OPERATION_TYPE_MODIFY_PROBLEM
    ]
  end
  
  # 获取操作类型的显示名称
  def operation_type_display
    case operation_type
    when OPERATION_TYPE_CREATE
      '创建工单'
    when OPERATION_TYPE_UPDATE
      '更新工单'
    when OPERATION_TYPE_STATUS_CHANGE
      '状态变更'
    when OPERATION_TYPE_ADD_PROBLEM
      '添加问题'
    when OPERATION_TYPE_REMOVE_PROBLEM
      '移除问题'
    when OPERATION_TYPE_MODIFY_PROBLEM
      '修改问题'
    else
      operation_type
    end
  end
  
  # 获取操作详情的哈希表示
  def details_hash
    return {} if details.blank?
    
    begin
      JSON.parse(details)
    rescue JSON::ParserError
      {}
    end
  end
  
  # 获取操作前状态的哈希表示
  def previous_state_hash
    return {} if previous_state.blank?
    
    begin
      JSON.parse(previous_state)
    rescue JSON::ParserError
      {}
    end
  end
  
  # 获取操作后状态的哈希表示
  def current_state_hash
    return {} if current_state.blank?
    
    begin
      JSON.parse(current_state)
    rescue JSON::ParserError
      {}
    end
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id work_order_id admin_user_id operation_type created_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[work_order admin_user]
  end
end