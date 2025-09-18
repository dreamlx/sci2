class Ability
  include CanCan::Ability

  def initialize(admin_user)
    admin_user ||= AdminUser.new
    
    if admin_user.super_admin?
      # 超级管理员拥有所有权限
      can :manage, :all
    else
      # 普通管理员的基础权限
      can :read, :all
      
      # 报销单相关权限
      can :create, Reimbursement
      can :update, Reimbursement
      can :show, Reimbursement
      
      # 工单相关权限
      can :create, WorkOrder
      can :update, WorkOrder
      can :show, WorkOrder
      
      # 费用明细相关权限
      can :create, FeeDetail
      can :update, FeeDetail
      can :show, FeeDetail
      
      # 操作历史相关权限
      can :create, OperationHistory
      can :update, OperationHistory
      can :show, OperationHistory
      
      # 禁止的操作（只有超级管理员可以执行）
      cannot :import, :all
      cannot :destroy, :all
      cannot [:create, :update, :destroy], AdminUser
      cannot [:create, :update, :destroy], FeeType
      cannot [:create, :update, :destroy], ProblemType
      cannot :assign, Reimbursement
      cannot :update_status, Reimbursement
      cannot :upload_attachment, Reimbursement
    end
  end
end