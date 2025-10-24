ActiveAdmin.register AdminUser do
  permit_params :email, :password, :password_confirmation, :role, :name, :telephone, :status

  menu priority: 10, label: '管理员用户', if: proc {
    AdminUserPolicy.new(current_admin_user).can_index?
  }

  # 权限控制和查询范围
  controller do
    include AuthorizationConcern

    # Define permission protections for all controller actions
    protect_action :index, with: 'AdminUserPolicy', method: :can_index?
    protect_action :show, with: 'AdminUserPolicy', method: :can_show?
    protect_action :create, with: 'AdminUserPolicy', method: :can_create?
    protect_action :update, with: 'AdminUserPolicy', method: :can_update?
    protect_action :destroy, with: 'AdminUserPolicy', method: :can_destroy?

    # Protect member actions
    protect_action :member_action, action_name: :soft_delete, with: 'AdminUserPolicy', method: :can_soft_delete?
    protect_action :member_action, action_name: :restore, with: 'AdminUserPolicy', method: :can_restore?

    # Protect batch actions
    protect_action :batch_action, action_name: :软删除, with: 'AdminUserPolicy', method: :can_batch_soft_delete?
    protect_action :batch_action, action_name: :恢复, with: 'AdminUserPolicy', method: :can_batch_restore?
    protect_action :batch_action, action_name: :设置为活跃, with: 'AdminUserPolicy', method: :can_batch_set_active?
    protect_action :batch_action, action_name: :设置为非活跃, with: 'AdminUserPolicy', method: :can_batch_set_inactive?

    def scoped_collection
      end_of_association_chain.exclude_deleted
    end

    def update
      policy = AdminUserPolicy.new(current_admin_user, resource)
      if policy.can_update_own_profile?
        # Allow self-update with restricted params
        allowed_params = %i[email name telephone]
        allowed_params += %i[password password_confirmation] if params[:admin_user][:password].present?
        params[:admin_user] = params[:admin_user].permit(*allowed_params)
      end
      super
    end
  end

  # Scopes for filtering
  scope :all, default: true do |users|
    users.exclude_deleted
  end
  scope :active_users do |users|
    users.exclude_deleted.active_users
  end
  scope :available do |users|
    users.exclude_deleted.available
  end
  scope :deleted do |users|
    users.deleted
  end

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :role
    column :status do |user|
      status_tag user.status_display, class: (case user.status
                                              when 'active'
                                                'ok'
                                              when 'inactive'
                                                'warning'
                                              when 'suspended'
                                                'error'
                                              when 'deleted'
                                                'error'
                                              else
                                                ''
                                              end)
    end
    column :telephone
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    column :deleted_at
    actions defaults: false do |user|
      policy = AdminUserPolicy.new(current_admin_user, user)

      item '查看', admin_admin_user_path(user), class: 'member_link' if policy.can_show?

      item '编辑', edit_admin_admin_user_path(user), class: 'member_link' if policy.can_edit?

      if policy.can_soft_delete? && !user.deleted?
        item '软删除', soft_delete_admin_admin_user_path(user),
             method: :put,
             data: { confirm: '确定要软删除此用户吗？' },
             class: 'member_link'
      end

      if policy.can_restore? && user.deleted?
        item '恢复', restore_admin_admin_user_path(user),
             method: :put,
             data: { confirm: '确定要恢复此用户吗？' },
             class: 'member_link'
      end

      if policy.can_destroy?
        item '删除', admin_admin_user_path(user),
             method: :delete,
             data: { confirm: '确定要永久删除此用户吗？此操作不可逆。' },
             class: 'member_link important'
      end
    end
  end

  filter :email
  filter :name
  filter :role, as: :select, collection: AdminUser.roles.keys
  filter :status, as: :select, collection: AdminUser.statuses.keys
  filter :telephone
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at
  filter :deleted_at

  show do
    attributes_table do
      row :id
      row :email
      row :name
      row :telephone
      row :role
      row :status do |user|
        status_tag user.status_display, class: status_class_for_user(user)
      end
      row :deleted_at
      row :current_sign_in_at
      row :last_sign_in_at
      row :sign_in_count
      row :created_at
      row :updated_at
    end

    # 显示关联的报销单分配
    if admin_user.assigned_reimbursements.any?
      panel '报销单分配记录' do
        table_for admin_user.assigned_reimbursements.recent_first.limit(10) do
          column :id
          column :报销单 do |assignment|
            link_to assignment.reimbursement.id, admin_reimbursement_path(assignment.reimbursement)
          end
          column :分配者 do |assignment|
            assignment.assigner.name
          end
          column :状态 do |assignment|
            assignment.is_active? ? '活跃' : '非活跃'
          end
          column :创建时间 do |assignment|
            assignment.created_at.strftime('%Y-%m-%d %H:%M')
          end
        end
      end
    end

    # 显示工单操作记录
    if admin_user.work_order_operations.any?
      panel '工单操作记录' do
        table_for admin_user.work_order_operations.recent_first.limit(10) do
          column :id
          column :工单 do |operation|
            link_to operation.work_order.id, admin_work_order_path(operation.work_order)
          end
          column :操作类型 do |operation|
            operation.operation_type_display
          end
          column :操作时间 do |operation|
            operation.created_at.strftime('%Y-%m-%d %H:%M')
          end
        end
      end
    end
  end

  form do |f|
    policy = AdminUserPolicy.new(current_admin_user, f.object)

    f.inputs '基本信息' do
      f.input :email if policy.can_update? || policy.can_update_own_profile?
      f.input :name if policy.can_update? || policy.can_update_own_profile?
      f.input :telephone if policy.can_update? || policy.can_update_own_profile?

      # Role and status only for super admins
      f.input :role, as: :select, collection: AdminUser.roles.keys, include_blank: false if policy.show_role_field?
      if policy.show_status_field?
        f.input :status, as: :select, collection: AdminUser.statuses.keys,
                         include_blank: false
      end

      # Password fields for new records or self password change
      if f.object.new_record? && policy.can_create?
        f.input :password
        f.input :password_confirmation
      elsif policy.can_change_own_password? && !f.object.new_record?
        f.input :password, hint: '留空则不修改密码'
        f.input :password_confirmation, hint: '请再次输入新密码'
      end
    end

    f.actions if policy.can_create? || policy.can_update? || policy.can_update_own_profile?
  end

  # 批量操作 - 基于Policy的权限控制
  batch_action :软删除, if: proc {
    AdminUserPolicy.new(current_admin_user).can_batch_soft_delete?
  } do |ids|
    batch_action_collection.find(ids).each do |user|
      user.soft_delete unless user.deleted?
    end
    redirect_to collection_path, notice: '已软删除选中的用户'
  end

  batch_action :恢复, if: proc {
    AdminUserPolicy.new(current_admin_user).can_batch_restore?
  } do |ids|
    batch_action_collection.find(ids).each do |user|
      user.restore if user.deleted?
    end
    redirect_to collection_path, notice: '已恢复选中的用户'
  end

  batch_action :设置为活跃, if: proc {
    AdminUserPolicy.new(current_admin_user).can_batch_set_active?
  } do |ids|
    batch_action_collection.find(ids).each do |user|
      user.update(status: 'active') unless user.deleted?
    end
    redirect_to collection_path, notice: '已设置选中的用户为活跃状态'
  end

  batch_action :设置为非活跃, if: proc {
    AdminUserPolicy.new(current_admin_user).can_batch_set_inactive?
  } do |ids|
    batch_action_collection.find(ids).each do |user|
      user.update(status: 'inactive') unless user.deleted?
    end
    redirect_to collection_path, notice: '已设置选中的用户为非活跃状态'
  end

  # 自定义成员操作 - 权限由AuthorizationConcern自动保护
  member_action :soft_delete, method: :put do
    resource.soft_delete
    redirect_to resource_path, notice: '用户已软删除'
  end

  member_action :restore, method: :put do
    resource.restore
    redirect_to resource_path, notice: '用户已恢复'
  end

  controller do
    def update
      if params[:admin_user][:password].blank? && params[:admin_user][:password_confirmation].blank?
        params[:admin_user].delete('password')
        params[:admin_user].delete('password_confirmation')
      end
      super
    end

    private

    def status_class_for_user(user)
      case user.status
      when 'active'
        'ok'
      when 'inactive'
        'warning'
      when 'suspended'
        'error'
      when 'deleted'
        'error'
      else
        ''
      end
    end
  end
end
