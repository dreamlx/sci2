ActiveAdmin.register FeeDetail do
  permit_params :reimbursement_id, :document_number, :fee_type, :amount, :fee_date,
                :verification_status, :payment_method, :notes

  menu parent: "数据管理", label: "费用明细"

  filter :document_number, as: :string, label: "报销单号"
  filter :fee_type
  filter :verification_status, as: :select, collection: ["pending", "problematic", "verified"]
  filter :payment_method
  filter :fee_date
  filter :created_at

  action_item :import, only: :index do
    link_to "导入费用明细", new_import_admin_fee_details_path
  end

  collection_action :new_import, method: :get do
    render "admin/shared/import_form", locals: {
      title: "导入费用明细",
      import_path: import_admin_fee_details_path,
      cancel_path: admin_fee_details_path,
      instructions: [
        "请上传CSV格式文件",
        "文件必须包含以下列：报销单号,费用类型,金额,费用日期,验证状态,支付方式,备注",
        "系统会根据报销单号关联到已存在的报销单",
        "如果费用明细已存在（根据报销单号+费用类型+金额+费用日期判断），将更新现有记录",
        "如果费用明细不存在，将创建新记录"
      ]
    }
  end

  collection_action :import, method: :post do
    unless params[:file].present?
      redirect_to new_import_admin_fee_details_path, alert: "请选择要导入的文件。"
      return
    end

    service = FeeDetailImportService.new(params[:file], current_admin_user)
    result = service.import

    if result[:success]
      notice_message = "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新."
      notice_message += " #{result[:errors]} 错误." if result[:errors].to_i > 0
      redirect_to admin_fee_details_path, notice: notice_message
    else
      alert_message = "导入失败: #{result[:errors].join(', ')}"
      alert_message += " 错误详情: #{result[:error_details].join('; ')}" if result[:error_details].present?
      redirect_to new_import_admin_fee_details_path, alert: alert_message
    end
  end

  index do
    selectable_column
    id_column
    column :reimbursement do |fee_detail|
      link_to fee_detail.document_number, admin_reimbursement_path(fee_detail.reimbursement) if fee_detail.reimbursement
    end
    column :fee_type
    column :amount do |fee_detail|
      number_to_currency(fee_detail.amount, unit: "¥")
    end
    column :fee_date
    column :verification_status do |fee_detail|
      status_tag fee_detail.verification_status
    end
    column :payment_method
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :reimbursement do |fee_detail|
        link_to fee_detail.document_number, admin_reimbursement_path(fee_detail.reimbursement) if fee_detail.reimbursement
      end
      row :fee_type
      row :amount do |fee_detail|
        number_to_currency(fee_detail.amount, unit: "¥")
      end
      row :fee_date
      row :verification_status do |fee_detail|
        status_tag fee_detail.verification_status
      end
      row :payment_method
      row :notes
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "费用明细信息" do
      f.input :document_number, as: :select, collection: Reimbursement.all.pluck(:invoice_number), include_blank: true
      f.input :fee_type
      f.input :amount, input_html: { min: 0.01 }
      f.input :fee_date, as: :datepicker
      f.input :verification_status, as: :select, collection: ["pending", "problematic", "verified"], include_blank: false
      f.input :payment_method
      f.input :notes
    end
    f.actions
  end
end