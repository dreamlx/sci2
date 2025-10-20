class Ability
  include CanCan::Ability

  def initialize(admin_user)
    admin_user ||= AdminUser.new

    # 如果用户被软删除，没有任何权限
    if admin_user.deleted?
      cannot :manage, :all
      return
    end

    if admin_user.super_admin?
      # 超级管理员拥有所有权限，但不能删除自己
      can :manage, :all
      cannot :destroy, AdminUser, id: admin_user.id

      # 软删除和恢复权限
      can %i[soft_delete restore], AdminUser
      cannot %i[soft_delete restore], AdminUser, id: admin_user.id

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

      # 明确的 STI 子类权限
      can :manage, CommunicationWorkOrder
      can :manage, AuditWorkOrder

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
      cannot %i[create update destroy], AdminUser
      cannot %i[create update destroy], FeeType
      cannot %i[create update destroy], ProblemType
      cannot :assign, Reimbursement
      cannot :update_status, Reimbursement
      cannot :upload_attachment, Reimbursement
      cannot %i[soft_delete restore], AdminUser
    end

    # 全局限制：不能对已删除的用户执行任何操作
    # 由于CanCan的accessible_by限制，我们改为在查询层面处理
    # 具体逻辑在AdminUser模型的scope中实现
  end
end
