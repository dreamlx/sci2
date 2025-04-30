ActiveAdmin.register_page "Imports" do
  menu false # 隐藏菜单项，仅用于API

  page_action :operation_histories, method: :get do
    render "admin/imports/operation_histories"
  end

  page_action :import_operation_histories, method: :post do
    unless params[:file].present?
      redirect_to operation_histories_admin_imports_path, alert: "请选择要导入的文件。"
      return
    end
    
    service = OperationHistoryImportService.new(params[:file], current_admin_user)
    result = service.import
    
    if result[:success]
      notice_message = "导入成功: #{result[:imported]} 创建, #{result[:skipped]} 跳过."
      notice_message += " #{result[:updated_reimbursements]} 报销单状态已更新." if result[:updated_reimbursements].to_i > 0
      notice_message += " #{result[:unmatched]} 未匹配." if result[:unmatched].to_i > 0
      notice_message += " #{result[:errors]} 错误." if result[:errors].to_i > 0
      redirect_to admin_reimbursements_path, notice: notice_message
    else
      alert_message = "导入失败: #{result[:errors].join(', ')}"
      alert_message += " 错误详情: #{result[:error_details].join('; ')}" if result[:error_details].present?
      redirect_to operation_histories_admin_imports_path, alert: alert_message
    end
  end
end