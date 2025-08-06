ActiveAdmin.register OperationHistory do
  # 设置为只读资源，只允许查看和导入，不允许创建、编辑和删除
  actions :index, :show
  
  menu parent: "数据管理", label: "操作历史"
  
  # 添加导入功能
  action_item :import, only: :index do
    link_to '导入操作历史', operation_histories_admin_imports_path
  end
  
  # 过滤器
  filter :document_number
  filter :form_type
  filter :applicant
  filter :employee_id
  filter :employee_company
  filter :employee_department
  filter :submitter
  filter :document_name
  filter :operation_type
  filter :operation_node
  filter :operator
  filter :currency
  filter :amount
  filter :operation_time
  filter :created_date
  
  # CSV 导出配置
  csv do
    column("表单类型") { |operation_history| operation_history.form_type || '-' }
    column("单据编号") { |operation_history| operation_history.document_number }
    column("申请人") { |operation_history| operation_history.applicant || '-' }
    column("员工工号") { |operation_history| operation_history.employee_id || '-' }
    column("员工公司") { |operation_history| operation_history.employee_company || '-' }
    column("员工部门") { |operation_history| operation_history.employee_department || '-' }
    column("员工部门路径") { |operation_history| operation_history.employee_department_path || '-' }
    column("员工单据公司") { |operation_history| operation_history.document_company || '-' }
    column("员工单据部门") { |operation_history| operation_history.document_department || '-' }
    column("员工单据部门路径") { |operation_history| operation_history.document_department_path || '-' }
    column("提交人") { |operation_history| operation_history.submitter || '-' }
    column("单据名称") { |operation_history| operation_history.document_name || '-' }
    column("币种") { |operation_history| operation_history.currency || '-' }
    column("金额") { |operation_history| operation_history.formatted_amount }
    column("创建日期") { |operation_history| operation_history.formatted_created_date }
    column("操作节点") { |operation_history| operation_history.operation_node || '-' }
    column("操作类型") { |operation_history| operation_history.operation_type }
    column("操作意见") { |operation_history| operation_history.notes || '-' }
    column("操作日期") { |operation_history| operation_history.formatted_operation_time }
    column("操作人") { |operation_history| operation_history.operator }
  end
  
  # 列表页
  index do
    selectable_column
    column :document_number, label: "单据编号"
    column :applicant, label: "申请人"
    column :employee_id, label: "员工工号"
    column :employee_company, label: "员工公司"
    column :employee_department, label: "员工部门"
    column :document_name, label: "单据名称"
    column :operation_node, label: "操作节点"
    column :operation_type, label: "操作类型"
    column :notes, label: "操作意见" do |operation_history|
      truncate(operation_history.notes || '', length: 50)
    end
    column :operation_time, label: "操作日期" do |operation_history|
      operation_history.formatted_operation_time
    end
    column :operator, label: "操作人"
    actions defaults: false do |operation_history|
      item "查看", admin_operation_history_path(operation_history)
    end
  end
  
  # 详情页
  show do
    attributes_table do
      row :document_number, label: "单据编号"
      row :form_type, label: "表单类型"
      row :applicant, label: "申请人"
      row :employee_id, label: "员工工号"
      row :employee_company, label: "员工公司"
      row :employee_department, label: "员工部门"
      row :employee_department_path, label: "员工部门路径"
      row :document_company, label: "员工单据公司"
      row :document_department, label: "员工单据部门"
      row :document_department_path, label: "员工单据部门路径"
      row :submitter, label: "提交人"
      row :document_name, label: "单据名称"
      row :currency, label: "币种"
      row :amount, label: "金额"
      row :created_date, label: "创建日期"
      row :operation_node, label: "操作节点"
      row :operation_type, label: "操作类型"
      row :notes, label: "操作意见"
      row :operation_time, label: "操作日期"
      row :operator, label: "操作人"
      row :created_at, label: "记录创建时间"
      row :updated_at, label: "记录更新时间"
    end
  end
end