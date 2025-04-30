ActiveAdmin.register OperationHistory do
  # 设置为只读资源，只允许查看和导入，不允许创建、编辑和删除
  actions :index, :show
  
  # 添加导入功能
  action_item :import, only: :index do
    link_to '导入操作历史', admin_imports_operation_histories_path
  end
  
  # 过滤器
  filter :document_number
  filter :operation_type
  filter :operator
  filter :operation_time
  
  # 列表页
  index do
    column :document_number
    column :operation_type
    column :operation_time
    column :operator
    column :notes
    actions defaults: false do |operation_history|
      item "查看", admin_operation_history_path(operation_history)
    end
  end
  
  # 详情页
  show do
    attributes_table do
      row :document_number
      row :operation_type
      row :operation_time
      row :operator
      row :notes
      row :form_type
      row :operation_node
      row :created_at
      row :updated_at
    end
  end
end