ActiveAdmin.register AdminUser do
  permit_params :email, :password, :password_confirmation, :role, :name, :telephone, :status

  menu priority: 10, label: "管理员用户"

  # Scopes for filtering
  scope :all, default: true
  scope :active_users
  scope :available
  scope :deleted

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :role
    column :status do |user|
      status_tag user.status_display, class: status_class_for_user(user)
    end
    column :telephone
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    column :deleted_at
    actions defaults: true do |user|
      if user.deleted?
        link_to '恢复', restore_admin_admin_user_path(user), method: :put, data: { confirm: '确定要恢复此用户吗？' }
      else
        link_to '软删除', soft_delete_admin_admin_user_path(user), method: :put, data: { confirm: '确定要软删除此用户吗？' }
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
    panel "报销单分配记录" do
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
    end if admin_user.assigned_reimbursements.any?
    
    # 显示工单操作记录
    panel "工单操作记录" do
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
    end if admin_user.work_order_operations.any?
  end

  form do |f|
    f.inputs "基本信息" do
      f.input :email
      f.input :name
      f.input :telephone
      f.input :role, as: :select, collection: AdminUser.roles.keys, include_blank: false
      f.input :status, as: :select, collection: AdminUser.statuses.keys, include_blank: false
      if f.object.new_record?
        f.input :password
        f.input :password_confirmation
      end
    end
    f.actions
  end

  # 批量操作
  batch_action :软删除 do |ids|
    batch_action_collection.find(ids).each do |user|
      user.soft_delete unless user.deleted?
    end
    redirect_to collection_path, notice: "已软删除选中的用户"
  end

  batch_action :恢复 do |ids|
    batch_action_collection.find(ids).each do |user|
      user.restore if user.deleted?
    end
    redirect_to collection_path, notice: "已恢复选中的用户"
  end

  batch_action :设置为活跃 do |ids|
    batch_action_collection.find(ids).each do |user|
      user.update(status: 'active') unless user.deleted?
    end
    redirect_to collection_path, notice: "已设置选中的用户为活跃状态"
  end

  batch_action :设置为非活跃 do |ids|
    batch_action_collection.find(ids).each do |user|
      user.update(status: 'inactive') unless user.deleted?
    end
    redirect_to collection_path, notice: "已设置选中的用户为非活跃状态"
  end

  # 自定义成员操作
  member_action :soft_delete, method: :put do
    resource.soft_delete
    redirect_to resource_path, notice: "用户已软删除"
  end

  member_action :restore, method: :put do
    resource.restore
    redirect_to resource_path, notice: "用户已恢复"
  end

  controller do
    def update
      if params[:admin_user][:password].blank? && params[:admin_user][:password_confirmation].blank?
        params[:admin_user].delete("password")
        params[:admin_user].delete("password_confirmation")
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
