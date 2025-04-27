ActiveAdmin.register CommunicationRecord do
  # 权限控制
  permit_params :communication_work_order_id, :content, :communicator_role,
                :communicator_name, :communication_method, :recorded_at

  # 菜单设置
  menu priority: 5, label: "沟通记录", parent: "沟通工单"

  # 过滤器
  filter :communication_work_order_id
  filter :communicator_role
  filter :communication_method
  filter :recorded_at
  filter :created_at

  # 列表页
  index do
    selectable_column
    id_column
    column :communication_work_order
    column :communicator_role
    column :communicator_name
    column :communication_method
    column :content
    column :recorded_at
    actions
  end

  # 详情页
  show do
    attributes_table do
      row :id
      row :communication_work_order
      row :content
      row :communicator_role
      row :communicator_name
      row :communication_method
      row :recorded_at
      row :created_at
      row :updated_at
    end
  end

  # 表单
  form do |f|
    f.inputs "沟通记录信息" do
      f.input :communication_work_order
      f.input :content
      f.input :communicator_role, as: :select, collection: ["auditor", "applicant", "manager", "other"]
      f.input :communicator_name
      f.input :communication_method, as: :select, collection: ["email", "phone", "system", "other"]
      f.input :recorded_at, as: :datepicker
    end
    f.actions
  end
end