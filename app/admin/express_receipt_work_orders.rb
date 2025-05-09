ActiveAdmin.register ExpressReceiptWorkOrder do
  permit_params :reimbursement_id, :tracking_number, :received_at, :courier_name, :creator_id

  menu priority: 3, label: "快递收单工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'

  controller do
    def scoped_collection
      super.includes(:reimbursement, :creator)
    end

    def create
      super do |resource|
        resource.creator_id ||= current_admin_user.id if resource.new_record? && resource.creator_id.blank?
      end
    end
  end

  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :tracking_number
  filter :courier_name
  filter :received_at
  filter :creator
  filter :created_at

  # 批量操作
  batch_action :mark_as_received do |ids|
    batch_action_collection.find(ids).each do |work_order|
      work_order.update(received_at: Time.current) unless work_order.received_at.present?
    end
    redirect_to collection_path, notice: "已将选中的工单标记为已收单"
  end

  # 操作按钮
  action_item :import, only: :index do
    link_to "导入快递收单", new_import_admin_express_receipt_work_orders_path
  end

  # 导入操作
  collection_action :new_import, method: :get do
    render "admin/express_receipt_work_orders/new_import"
  end

  collection_action :import, method: :post do
    unless params[:file].present?
      redirect_to new_import_admin_express_receipt_work_orders_path, alert: "请选择要导入的文件。"
      return
    end

    service = ExpressReceiptImportService.new(params[:file], current_admin_user)
    result = service.import

    if result[:success]
      notice_message = "导入成功: #{result[:created]} 创建, #{result[:skipped]} 跳过."
      notice_message += " #{result[:unmatched]} 未匹配." if result[:unmatched].to_i > 0
      notice_message += " #{result[:errors]} 错误." if result[:errors].to_i > 0
      redirect_to admin_express_receipt_work_orders_path, notice: notice_message
    else
      alert_message = "导入失败: #{result[:errors].join(', ')}"
      alert_message += " 错误详情: #{result[:error_details].join('; ')}" if result[:error_details].present?
      redirect_to new_import_admin_express_receipt_work_orders_path, alert: alert_message
    end
  end

  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :tracking_number
    column :courier_name
    column :received_at
    column :status do |wo| status_tag wo.status end
    column :creator
    column :created_at
    actions
  end

  # 详情页
  show title: proc{|wo| "快递收单工单 ##{wo.id}" } do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
          row :type
          row :status do |wo| status_tag wo.status end
          row :tracking_number
          row :courier_name
          row :received_at
          row :creator
          row :created_at
          row :updated_at
        end
      end

      tab "关联审核工单" do
        panel "审核工单信息" do
          table_for resource.reimbursement.audit_work_orders.order(created_at: :desc) do
            column(:id) { |awo| link_to awo.id, admin_audit_work_order_path(awo) }
            column(:status) { |awo| status_tag awo.status }
            column :creator
            column :created_at
          end
        end
      end

      tab "状态变更历史" do
        panel "状态变更历史" do
          table_for resource.work_order_status_changes.order(changed_at: :desc) do
            column :from_status
            column :to_status
            column :changed_at
            column :changer do |change| change.changer&.email end
          end
        end
      end
    end
    active_admin_comments
  end

  # 表单页
  form do |f|
    f.inputs "快递收单工单信息" do
      f.input :reimbursement_id, as: :select,
              collection: Reimbursement.all.map { |r| ["#{r.invoice_number} - #{r.applicant}", r.id] },
              input_html: { disabled: !f.object.new_record? }
      f.input :tracking_number
      f.input :courier_name
      f.input :received_at, as: :datepicker
    end
    f.actions
  end
end