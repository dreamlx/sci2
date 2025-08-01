ActiveAdmin.register_page "Imports" do
  menu priority: 10, label: "数据导入", parent: "数据管理"

  # 操作历史导入
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
      
      if result[:unmatched].to_i > 0
        unmatched_doc_numbers = result[:unmatched_histories].map { |h| h[:document_number] }
        if unmatched_doc_numbers.size <= 5
          notice_message += " #{result[:unmatched]} 未匹配: #{unmatched_doc_numbers.join(', ')}."
        else
          notice_message += " #{result[:unmatched]} 未匹配: #{unmatched_doc_numbers.first(5).join(', ')} 等."
        end
      end
      
      notice_message += " #{result[:errors]} 错误." if result[:errors].to_i > 0
      redirect_to admin_reimbursements_path, notice: notice_message
    else
      alert_message = "导入失败: #{result[:error_details] ? result[:error_details].join(', ') : (result[:errors].is_a?(Array) ? result[:errors].join(', ') : result[:errors])}"
      redirect_to operation_histories_admin_imports_path, alert: alert_message
    end
  end
  
  # 问题代码导入
  page_action :new, method: :get do
    @resource = params[:resource]
    case @resource
    when 'problem_codes'
      render "admin/imports/problem_codes", layout: 'active_admin'
    else
      redirect_to admin_dashboard_path, alert: "未知的导入资源类型"
    end
  end
  
  page_action :import_problem_codes, method: :post do
    unless params[:file].present?
      redirect_to '/admin/imports/new?resource=problem_codes', alert: "请选择要导入的文件。"
      return
    end
    
    begin
      service = ProblemCodeImportService.new(params[:file].path)
      result = service.import
      
      if result[:success]
        notice_message = "导入成功: #{result[:imported_fee_types]} 费用类型, #{result[:imported_problem_types]} 问题类型."
        notice_message += " #{result[:updated_fee_types]} 费用类型更新, #{result[:updated_problem_types]} 问题类型更新." if result[:updated_fee_types].to_i > 0 || result[:updated_problem_types].to_i > 0
        
        # 保存详细信息到会话，以便在结果页面显示
        session[:import_result_details] = result[:details]
        
        # 使用直接路径而不是路由辅助方法
        redirect_to '/admin/imports/import_results', notice: notice_message
      else
        alert_message = "导入失败: #{result[:error]}"
        redirect_to '/admin/imports/new?resource=problem_codes', alert: alert_message
      end
    rescue => e
      redirect_to '/admin/imports/new?resource=problem_codes', alert: "导入过程中发生错误: #{e.message}"
    end
  end
  
  # 导入结果页面
  page_action :import_results, method: :get do
    render "admin/imports/import_results"
  end
  
  # 主页
  content title: "数据导入" do
    div class: "blank_slate_container", id: "dashboard_default_message" do
      span class: "blank_slate" do
        span "选择要导入的数据类型"
        small "点击下方链接进入相应的导入页面"
      end
    end
    
    div class: "admin_imports" do
      ul do
        li link_to "操作历史导入", operation_histories_admin_imports_path
        li link_to "问题代码导入", '/admin/imports/new?resource=problem_codes'
      end
    end
  end
end