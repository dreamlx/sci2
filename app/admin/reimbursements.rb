ActiveAdmin.register Reimbursement do
  # 添加附件上传的成员动作
  member_action :upload_attachment, method: :post do
    service = AttachmentUploadService.new(resource, params)
    result = service.upload

    if result[:success]
      redirect_to admin_reimbursement_path(resource), notice: "附件上传成功！已创建费用明细 ##{result[:fee_detail].id}"
    else
      redirect_to admin_reimbursement_path(resource), alert: "上传失败：#{result[:error]}"
    end
  end
  permit_params :invoice_number, :document_name, :applicant, :applicant_id, :company, :department,
                :amount, :receipt_status, :status, :receipt_date, :submission_date,
                :is_electronic, :external_status, :approval_date, :approver_name,
                :related_application_number, :accounting_date, :document_tags,
                :erp_current_approval_node, :erp_current_approver, :erp_flexible_field_2,
                :erp_node_entry_time, :erp_first_submitted_at, :erp_flexible_field_8

  menu priority: 2, label: "报销单管理"

  # 重新添加scoped_collection方法来确保scope计数使用正确的基础集合
  controller do
    # 当用户查看详情页面时，标记当前报销单为已查看
    def show
      authorize! :read, resource
      resource.mark_as_viewed! if resource.has_unread_updates?
      super
    end
    
    def create
      authorize! :create, Reimbursement
      super
    end
    
    def update
      authorize! :update, resource
      super
    end
    
    def destroy
      authorize! :destroy, resource
      super
    end
    
    # 重写apply_sorting方法来处理通知状态的自定义排序
    def apply_sorting(chain)
      # 检查是否是has_updates字段的排序
      if params[:order].present? && params[:order].include?('has_updates')
        # 提取排序方向
        direction = params[:order].include?('_desc') ? 'DESC' : 'ASC'
        
        # 应用自定义排序逻辑
        return chain.order(
          Arel.sql("has_updates #{direction}, last_update_at DESC NULLS LAST")
        )
      end
      
      # 对于其他字段，使用默认的排序逻辑
      super
    end
    
    private
    
    # 简化的scope逻辑 - 统一所有角色的权限处理
    def scoped_collection
      service = ReimbursementScopeService.new(current_admin_user, params)
      service.filtered_collection(end_of_association_chain)
    end
  end

  # 过滤器
  filter :invoice_number
  filter :applicant
  filter :company, label: "公司", as: :string
  filter :department, label: "部门", as: :string
  filter :status, label: "内部状态", as: :select, collection: [
    ['待处理', 'pending'],
    ['处理中', 'processing'],
    ['已关闭', 'closed']
  ]
  filter :erp_current_approval_node, label: "当前审批节点", as: :select, collection: -> {
    Reimbursement.where.not(erp_current_approval_node: [nil, '']).distinct.pluck(:erp_current_approval_node).compact.sort
  }
  filter :erp_current_approver, label: "当前审批人", as: :select, collection: -> {
    Reimbursement.where.not(erp_current_approver: [nil, '']).distinct.pluck(:erp_current_approver).compact.sort
  }
  filter :external_status, label: "外部状态", as: :select, collection: ["审批中", "已付款", "待付款", "待审核"]
  filter :receipt_status, as: :select, collection: ["pending", "received"]
  filter :is_electronic, as: :boolean
  filter :document_tags, label: "单据标签", as: :string
  filter :created_at
  filter :approval_date
  filter :current_assignee_id, as: :select, collection: -> { AdminUser.available.map { |u| [u.name.presence || u.email, u.id] } }, label: "Current Assignee"
  filter :with_unread_updates, label: '有新通知', as: :boolean

  # 列表页范围过滤器 - 使用标准ActiveRecord scope确保计数一致性
  # 设置"所有"为默认scope，让用户默认看到所有报销单
  scope :all, default: true, show_count: false
  
  # 分配给当前用户的报销单
  scope :assigned_to_me, show_count: false do |reimbursements|
    reimbursements.assigned_to_user(current_admin_user.id)
  end
  
  # 有新通知的scope - 只显示分配给当前用户且有未读更新的报销单
  scope "有新通知", :with_unread_updates, show_count: false do |reimbursements|
    reimbursements.assigned_with_unread_updates(current_admin_user.id)
  end
  
  # 状态相关的scope - 只显示分配给当前用户且状态匹配的报销单
  scope :pending, show_count: false do |reimbursements|
    reimbursements.assigned_to_user(current_admin_user.id).where(status: 'pending')
  end
  
  scope :processing, show_count: false do |reimbursements|
    reimbursements.assigned_to_user(current_admin_user.id).where(status: 'processing')
  end
  
  scope :closed, show_count: false do |reimbursements|
    reimbursements.assigned_to_user(current_admin_user.id).where(status: 'closed')
  end
  
  # 未分配的报销单 - 所有人都可以看到
  scope :unassigned, show_count: false do |reimbursements|
    reimbursements.left_joins(:active_assignment).where(reimbursement_assignments: { id: nil }, status: 'pending')
  end

  # 批量操作
  
  # 批量分配报销单 - 直接进行权限检查
  batch_action :assign_to,
               title: "批量分配报销单",
               if: proc {
                 true # 总是显示，但根据权限决定是否禁用
               },
               class: proc {
                 if params[:scope] == 'unassigned'
                   current_admin_user.super_admin? ? 'primary_action' : 'disabled_action'
                 else
                   current_admin_user.super_admin? ? nil : 'disabled_action'
                 end
               },
               form: -> {
    {
      assignee: AdminUser.available.map { |u| [u.email, u.id] },
      notes: :text
    }
  } do |ids, inputs|
    policy = ReimbursementPolicy.new(current_admin_user)
    unless policy.can_batch_assign?
      redirect_to collection_path, alert: policy.authorization_error_message(action: :batch_assign)
      return
    end
    
    service = ReimbursementAssignmentService.new(current_admin_user)
    results = service.batch_assign(ids, inputs[:assignee], inputs[:notes])
    
    redirect_to collection_path, notice: "成功分配 #{results.size} 个报销单"
  end

  # 操作按钮
  action_item :import, only: :index do
    link_to "导入报销单", new_import_admin_reimbursements_path
  end
  
  action_item :import_operation_histories, only: :index do
    link_to "导入操作历史", operation_histories_admin_imports_path
  end
  
  
  # 移除默认的编辑和删除按钮
  config.action_items.delete_if { |item| item.name == :edit || item.name == :destroy }
  
  # 添加自定义按钮，按照指定顺序排列
  action_item :new_audit_work_order, only: :show, priority: 0, if: proc { !resource.closed? } do
    link_to "新建审核工单", new_admin_audit_work_order_path(reimbursement_id: resource.id)
  end
  
  action_item :new_communication_work_order, only: :show, priority: 1, if: proc { !resource.closed? } do
    link_to "新建沟通工单", new_admin_communication_work_order_path(reimbursement_id: resource.id)
  end
  
  action_item :edit_reimbursement, only: :show, priority: 2, if: proc { !resource.closed? } do
    link_to "编辑报销单", edit_admin_reimbursement_path(resource)
  end
  
  action_item :delete_reimbursement, only: :show, priority: 3, if: proc { !resource.closed? } do
    link_to "删除报销单", admin_reimbursement_path(resource),
            method: :delete,
            data: { confirm: "确定要删除此报销单吗？此操作不可逆。" }
  end

  # ADDED: "处理完成" (Close) button, uses existing :close member_action
  action_item :close_reimbursement, label: "处理完成", only: :show, priority: 4, if: proc { resource.processing? && !resource.closed? } do
    link_to "处理完成", close_admin_reimbursement_path(resource), method: :put, data: { confirm: "确定要完成处理此报销单吗 (状态将变为 Closed)?" }
  end

  # ADDED: "取消完成" (Reopen) button
  action_item :reopen_reimbursement, label: "取消完成", only: :show, priority: 4, if: proc { resource.closed? } do
    link_to "取消完成", reopen_reimbursement_admin_reimbursement_path(resource), method: :put, data: { confirm: "确定要取消完成此报销单吗 (状态将变为 Processing)?" }
  end

  # Manual Override Controls - 手动状态覆盖控制按钮
  action_item :manual_override_section, label: "手动状态控制", only: :show, priority: 10, if: proc { ReimbursementPolicy.new(current_admin_user).can_manual_override? } do
    content_tag :div, class: "manual-override-controls", style: "margin: 10px 0; padding: 10px; border: 2px solid #ff6b35; border-radius: 5px; background-color: #fff3f0;" do
      content_tag(:h4, "⚠️ 手动状态覆盖控制", style: "margin: 0 0 10px 0; color: #ff6b35;") +
      content_tag(:p, "注意：手动状态更改将覆盖系统自动逻辑，请谨慎使用！", style: "margin: 0 0 10px 0; font-size: 12px; color: #666;") +
      content_tag(:div, class: "button-group") do
        [
          link_to("设为待处理", manual_set_pending_admin_reimbursement_path(resource),
                  method: :put, class: "button",
                  data: { confirm: "确定要手动设置状态为'待处理'吗？这将覆盖系统逻辑。" },
                  style: "margin-right: 5px; background-color: #ffa500; color: white; padding: 5px 10px; text-decoration: none; border-radius: 3px;"),
          link_to("设为处理中", manual_set_processing_admin_reimbursement_path(resource),
                  method: :put, class: "button",
                  data: { confirm: "确定要手动设置状态为'处理中'吗？这将覆盖系统逻辑。" },
                  style: "margin-right: 5px; background-color: #007bff; color: white; padding: 5px 10px; text-decoration: none; border-radius: 3px;"),
          link_to("设为已关闭", manual_set_closed_admin_reimbursement_path(resource),
                  method: :put, class: "button",
                  data: { confirm: "确定要手动设置状态为'已关闭'吗？这将覆盖系统逻辑。" },
                  style: "margin-right: 5px; background-color: #28a745; color: white; padding: 5px 10px; text-decoration: none; border-radius: 3px;"),
          (link_to("重置手动覆盖", reset_manual_override_admin_reimbursement_path(resource),
                   method: :put, class: "button",
                   data: { confirm: "确定要重置手动覆盖吗？状态将根据系统逻辑自动确定。" },
                   style: "background-color: #6c757d; color: white; padding: 5px 10px; text-decoration: none; border-radius: 3px;") if resource.manual_override?)
        ].compact.join(" ").html_safe
      end
    end
  end

  # 导入操作
  collection_action :new_import, method: :get do
    render "admin/shared/import_form_with_progress", locals: {
      title: "导入报销单",
      import_path: import_admin_reimbursements_path,
      cancel_path: admin_reimbursements_path,
      instructions: [
        "请上传CSV或Excel格式文件",
        "文件必须包含以下列：报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,收单状态,收单日期,关联申请单号,提交报销日期,记账日期,报销单状态 (此列的值将导入到外部状态字段),当前审批节点,当前审批人,报销单审核通过日期,审核通过人,报销金额（单据币种）,弹性字段2,当前审批节点转入时间,首次提交时间,单据标签,弹性字段8",
        "如果报销单已存在（根据报销单单号判断），将更新现有记录",
        "如果报销单不存在，将创建新记录",
        "⚡ 已启用批量优化，大文件导入速度提升30-40倍"
      ]
    }
  end

  collection_action :import, method: :post do
    authorize! :import, :all
    # 确保文件参数存在
    unless params[:file].present?
       redirect_to new_import_admin_reimbursements_path, alert: "请选择要导入的文件。"
       return
    end
    # 使用优化后的批量报销单导入服务
    service = SimpleBatchReimbursementImportService.new(params[:file], current_admin_user)
    result = service.import

    if result[:success]
      # 增强的成功消息，包含详细统计信息
      notice_message = "🎉 报销单导入成功完成！"
      notice_message += " 📊 处理结果: #{result[:created]}条新增, #{result[:updated]}条更新"
      notice_message += ", #{result[:errors]}条错误记录" if result[:errors].to_i > 0
      
      # 添加性能信息
      if result[:processing_time]
        processing_time = result[:processing_time].round(2)
        total_records = (result[:created].to_i + result[:updated].to_i)
        if total_records > 0 && processing_time > 0
          records_per_second = (total_records / processing_time).round(0)
          notice_message += " ⚡ 处理速度: #{records_per_second}条/秒, 耗时#{processing_time}秒"
        end
      end
      
      redirect_to admin_reimbursements_path, notice: notice_message
    else
      # 增强的错误消息，提供更清晰的错误信息
      error_msg = result[:error_details] ? result[:error_details].join(', ') : result[:errors]
      alert_message = "❌ 报销单导入失败: #{error_msg}"
      redirect_to new_import_admin_reimbursements_path, alert: alert_message
    end
  end

  # CSV 导出配置
  csv do
    column("报销单单号") { |reimbursement| reimbursement.invoice_number }
    column("单据名称") { |reimbursement| reimbursement.document_name }
    column("报销单申请人") { |reimbursement| reimbursement.applicant }
    column("报销单申请人工号") { |reimbursement| reimbursement.applicant_id }
    column("申请人公司") { |reimbursement| reimbursement.company }
    column("申请人部门") { |reimbursement| reimbursement.department }
    column("收单状态") { |reimbursement| reimbursement.receipt_status == 'received' ? '已收单' : '未收单' }
    column("收单日期") { |reimbursement| reimbursement.receipt_date&.strftime('%Y-%m-%d %H:%M:%S') || '0' }
    column("关联申请单号") { |reimbursement| reimbursement.related_application_number }
    column("提交报销日期") { |reimbursement| reimbursement.submission_date&.strftime('%Y-%m-%d %H:%M:%S') || '0' }
    column("记账日期") { |reimbursement| reimbursement.accounting_date&.strftime('%Y-%m-%d') || '0' }
    column("报销单状态") { |reimbursement| reimbursement.external_status }
    column("当前审批节点") { |reimbursement| reimbursement.erp_current_approval_node || '0' }
    column("当前审批人") { |reimbursement| reimbursement.erp_current_approver || '0' }
    column("报销单审核通过日期") { |reimbursement| reimbursement.approval_date&.strftime('%Y-%m-%d %H:%M:%S') || '0' }
    column("审核通过人") { |reimbursement| reimbursement.approver_name }
    column("报销金额（单据币种）") { |reimbursement| reimbursement.amount }
    column("弹性字段2") { |reimbursement| reimbursement.erp_flexible_field_2 }
    column("当前审批节点转入时间") { |reimbursement| reimbursement.erp_node_entry_time&.strftime('%Y-%m-%d %H:%M:%S') || '0' }
    column("首次提交时间") { |reimbursement| reimbursement.erp_first_submitted_at&.strftime('%Y-%m-%d %H:%M:%S') || '0' }
    column("单据标签") { |reimbursement| reimbursement.document_tags }
    column("弹性字段8") { |reimbursement| reimbursement.erp_flexible_field_8 || '0' }
    column("内部状态") { |reimbursement| reimbursement.status.upcase }
    column("Current Assignee") { |reimbursement| reimbursement.current_assignee&.email || "未分配" }
    column("创建时间") { |reimbursement| reimbursement.created_at.strftime('%Y年%m月%d日 %H:%M') }
    column("更新时间") { |reimbursement| reimbursement.updated_at.strftime('%Y年%m月%d日 %H:%M') }
  end

  # === 修改默认排序 ===
  
  # 设置默认排序：有更新的优先，然后按最新更新时间
  config.sort_order = 'has_updates_desc,last_update_at_desc'
  
  # 列表页
  index do
    # 添加角色和权限提示信息
    div class: "role_notice_panel" do
      policy = ReimbursementPolicy.new(current_admin_user)

      div class: "role_info" do
        span "当前角色: #{policy.role_display_name}", class: "role_badge"
      end

      unless policy.can_assign?
        div class: "permission_notice" do
          span policy.authorization_error_message(action: :assign), class: "warning_text"
        end
      end
    end
    
    selectable_column
    column :invoice_number, label: "报销单单号"
    column :erp_flexible_field_2, label: "弹性字段2"
    column :document_name, label: "单据名称"
    column :applicant, label: "报销单申请人"
    column :applicant_id, label: "报销单申请人工号"
    column :company, label: "申请人公司"
    column :department, label: "申请人部门"
    column :amount, label: "报销金额（单据币种）" do |reimbursement| 
      reimbursement.amount
    end
    column :receipt_status, label: "收单状态" do |reimbursement|
      reimbursement.receipt_status == 'received' ? '已收单' : '未收单'
    end
    column :receipt_date, label: "收单日期" do |reimbursement|
      reimbursement.receipt_date&.strftime('%Y-%m-%d %H:%M:%S') || '0'
    end
    column :external_status, label: "报销单状态"
    # column :erp_current_approval_node, label: "当前审批节点" do |reimbursement|
    #   reimbursement.erp_current_approval_node || '-'
    # end
    # column :erp_node_entry_time, label: "当前审批节点转入时间" do |reimbursement|
    #   reimbursement.erp_node_entry_time&.strftime('%Y-%m-%d %H:%M:%S') || '-'
    # end
    column :approval_date, label: "报销单审核通过日期" do |reimbursement|
      reimbursement.approval_date&.strftime('%Y-%m-%d') || '-'
    end
    column "内部状态", :status do |reimbursement| 
      status_tag reimbursement.status.upcase
    end
    column :current_assignee, label: "Current Assignee" do |reimbursement|
      reimbursement.current_assignee&.email || "未分配"
    end
    # 修改：统一的通知状态列，支持排序
    # 使用正确的ActiveAdmin语法来启用排序UI和功能
    column "通知状态", :has_updates, sortable: :has_updates do |reimbursement|
      if reimbursement.has_unread_updates?
        status_tag "有更新", class: "warning"
      else
        status_tag "无更新", class: "completed"
      end
    end
    
    # 新增：最新更新时间列，支持排序
    # column "最新更新", :last_update_at, sortable: true do |reimbursement|
    #   if reimbursement.last_update_at
    #     time_ago_in_words(reimbursement.last_update_at) + "前"
    #   else
    #     "-"
    #   end
    # end
    actions defaults: false do |reimbursement|
      item "查看", admin_reimbursement_path(reimbursement), class: "member_link"
    end
  end

  # 详情页
  show title: proc{|r| "报销单 ##{r.invoice_number}" } do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :invoice_number
          row :document_name
          row :applicant
          row :applicant_id
          row :company
          row :department
          row :amount do |reimbursement| number_to_currency(reimbursement.amount, unit: "¥") end
          row "内部状态", :status do |reimbursement| status_tag reimbursement.status end
          row "外部状态", :external_status do |reimbursement|
            reimbursement.external_status.presence || "空" # Display "空" if value is blank
          end
          row :receipt_status do |reimbursement| status_tag reimbursement.receipt_status end
          row :receipt_date
          row :submission_date
          row :is_electronic
          row :approval_date
          row :approver_name
          row :related_application_number
          row :accounting_date
          row :document_tags
          row :erp_current_approval_node
          row :erp_current_approver
          row :erp_flexible_field_2
          row :erp_node_entry_time
          row :erp_first_submitted_at
          row :erp_flexible_field_8
          row :created_at
          row :updated_at
        end

        panel "费用明细信息" do
          table_for resource.fee_details.includes(:work_orders).order(
            Arel.sql("CASE WHEN verification_status = 'problematic' THEN 0 ELSE 1 END"),
            created_at: :desc
          ) do
            column("费用明细id") { |fd| link_to fd.id, admin_fee_detail_path(fd) }
            column "关联工单" do |fee_detail|
              latest_wo = fee_detail.latest_associated_work_order
              if latest_wo
                link_to "##{latest_wo.id}", [:admin, latest_wo]
              else
                "无"
              end
            end
            column "验证状态", :verification_status do |fd| status_tag fd.verification_status end
            column :fee_type
            column "费用日期", :fee_date do |fd|
              fd.fee_date&.strftime("%Y-%m-%d") || "未设置"
            end
            column "金额", :amount do |fd| number_to_currency(fd.amount, unit: "¥") end
            column "问题类型" do |fee_detail|
              latest_wo = fee_detail.latest_associated_work_order
              if latest_wo && latest_wo.problem_types.any?
                problem_details = latest_wo.problem_types.map do |problem_type|
                  "#{problem_type.legacy_problem_code}-#{problem_type.title}-#{problem_type.sop_description}+#{problem_type.standard_handling}"
                end.join("\n")
                
                content_tag(:pre, problem_details,
                  class: "problem-type-plain-text",
                  style: "white-space: pre-wrap; margin: 0; font-family: monospace; font-size: 12px;")
              else
                "无"
              end
            end
            column "审核意见" do |fee_detail|
              latest_wo = fee_detail.latest_associated_work_order
              if latest_wo&.audit_comment.present?
                content_tag(:div, latest_wo.audit_comment,
                  style: "max-width: 200px; word-wrap: break-word; font-size: 12px;")
              else
                "无"
              end
            end
          end
        end

        # New panel to display total amount again for double check
        div "报销总金额复核" do
          hr 
          attributes_table_for resource do
            row :amount, label: "总金额" do |reimbursement| 
              strong { number_to_currency(reimbursement.amount, unit: "¥") }
            end
          end
        end

        panel "外部操作历史记录" do
          table_for resource.operation_histories.order(created_at: :desc) do
            column("记录ID") { |history| link_to history.id, [:admin, history] }
            column :operation_type
            column :operator
            column :operation_time
            column :notes
          end
        end
        
      end

      tab "快递收单工单" do
        panel "快递收单工单信息" do
          table_for resource.express_receipt_work_orders.order(created_at: :desc) do
            column(:id) { |wo| link_to wo.id, admin_express_receipt_work_order_path(wo) }
            column "Filling ID", :filling_id
            column :tracking_number
            column :received_at
            column :courier_name
            column(:status) { |wo| status_tag wo.status }
            column :creator
            column :created_at
          end
        end
      end

      tab "审核工单" do
        panel "审核工单信息" do
          table_for resource.audit_work_orders.includes(:creator).order(created_at: :desc) do
            column(:id) { |wo| link_to wo.id, admin_audit_work_order_path(wo) }
            column(:status) { |wo| status_tag wo.status }
            column("处理结果", :audit_result) { |wo| status_tag wo.audit_result if wo.audit_result.present? }
            column :audit_date
            column :creator
            column :created_at
          end
        end
         div class: "action_items" do
            span class: "action_item" do
              link_to "新建审核工单", new_admin_audit_work_order_path(reimbursement_id: resource.id), class: "button"
            end
         end
      end

      tab "沟通工单" do
        panel "沟通工单信息" do
          table_for resource.communication_work_orders.order(created_at: :desc) do
             column(:id) { |wo| link_to wo.id, admin_communication_work_order_path(wo) }
             column(:status) { |wo| status_tag wo.status }
             column :initiator_role
             column :creator
             column :created_at
          end
        end
         div class: "action_items" do
            span class: "action_item" do
              link_to "新建沟通工单", new_admin_communication_work_order_path(reimbursement_id: resource.id), class: "button"
            end
         end
      end

      tab "所有关联工单" do
        panel "所有关联工单信息" do
          table_for resource.work_orders.includes(:creator, :problem_types).order(created_at: :desc) do
            column("工单ID") { |wo| link_to wo.id, [:admin, wo] } # Links to specific work order type show page
            column("工单类型") { |wo| wo.model_name.human } # Or wo.type if you prefer the raw type string
            column("状态") { |wo| status_tag wo.status }
            column "创建人", :creator
            column "创建时间", :created_at
            column "审核结果" do |work_order|
              if work_order.audit_result.present?
                content_tag(:div, work_order.audit_result,
                  style: "max-width: 150px; word-wrap: break-word; font-size: 12px;")
              else
                "无"
              end
            end
            column "审核意见" do |work_order|
              if work_order.audit_comment.present?
                content_tag(:div, work_order.audit_comment,
                  style: "max-width: 200px; word-wrap: break-word; font-size: 12px;")
              else
                "无"
              end
            end
            column "问题详情" do |work_order|
              if work_order.problem_types.any?
                problem_details = work_order.problem_types.map do |problem_type|
                  [
                    "工单号: ##{work_order.id}",
                    "问题类型: #{problem_type.legacy_problem_code}",
                    "标题: #{problem_type.title}",
                    "SOP描述: #{problem_type.sop_description}",
                    "处理方法: #{problem_type.standard_handling}"
                  ].join("\n")
                end
                content_tag(:div, class: 'problem-details-container') do
                  content_tag(:pre, problem_details.join("\n\n"), class: 'problem-details')
                end
              else
                "无问题详情"
              end
            end
          end
        end
        
        # Add custom CSS for problem details
        style do
          %Q{
            .problem-details-container {
              max-height: 200px;
              overflow-y: auto;
              background-color: #f9f9f9;
              border: 1px solid #ddd;
              border-radius: 4px;
              padding: 8px;
            }
            .problem-details {
              white-space: pre-wrap;
              margin: 0;
              font-family: monospace;
              font-size: 12px;
            }
            .problem-type-display {
              max-width: 300px;
              overflow: hidden;
              text-overflow: ellipsis;
            }
            .problem-type-item {
              display: inline-block;
              margin-bottom: 3px;
            }
          }
        end
      end
      
      tab "附件管理 (#{resource.fee_details.joins(:attachments_attachments).distinct.count})" do
        panel "上传新附件" do
          form action: upload_attachment_admin_reimbursement_path(resource), method: :post, enctype: "multipart/form-data" do
            input type: :hidden, name: :authenticity_token, value: form_authenticity_token
            div class: "inputs" do
              ol do
                li do
                  label "选择文件", for: "attachments"
                  input type: :file, name: "attachments[]", id: "attachments", multiple: true, required: true
                end
                li do
                  label "附件说明", for: "notes"
                  textarea name: "notes", id: "notes", placeholder: "可填写附件描述信息"
                end
              end
            end
            div class: "actions" do
              input type: :submit, value: "上传附件", class: "button"
            end
          end
        end
        
        panel "报销单附件总览" do
          fee_details_with_attachments = resource.fee_details.includes(attachments_attachments: :blob).select { |fd| fd.attachments.attached? }
          
          if fee_details_with_attachments.any?
            div class: "attachments-overview", style: "margin-bottom: 20px; padding: 15px; background: #f0f8ff; border-radius: 5px;" do
              strong "附件统计："
              br
              span "总费用明细数: #{resource.fee_details.count}个"
              br
              span "有附件的费用明细: #{fee_details_with_attachments.count}个"
              br
              total_attachments = fee_details_with_attachments.sum(&:attachment_count)
              total_size = fee_details_with_attachments.sum(&:attachment_total_size)
              span "总附件数: #{total_attachments}个"
              br
              span "总大小: #{number_to_human_size(total_size)}"
            end
            
            table_for fee_details_with_attachments do
              column "费用明细ID" do |fd|
                link_to fd.id, admin_fee_detail_path(fd)
              end
              column "费用类型", :fee_type
              column "金额", :amount do |fd|
                number_to_currency(fd.amount, unit: "¥")
              end
              column "附件概览" do |fd|
                div class: "attachment-preview", style: "display: flex; flex-wrap: wrap; gap: 10px;" do
                  fd.attachments.limit(3).each do |attachment|
                    div class: "attachment-item", style: "border: 1px solid #ddd; padding: 8px; border-radius: 3px; max-width: 120px;" do
                      if attachment.image?
                        image_tag attachment.variant(resize_to_limit: [60, 60]),
                                 style: "max-width: 60px; height: auto; display: block; margin-bottom: 5px;"
                      else
                        div style: "text-align: center; padding: 15px; background: #f5f5f5;" do
                          case attachment.content_type
                          when 'application/pdf'
                            span "📄", style: "font-size: 20px;"
                          when /word/
                            span "📝", style: "font-size: 20px;"
                          when /excel|sheet/
                            span "📊", style: "font-size: 20px;"
                          else
                            span "📎", style: "font-size: 20px;"
                          end
                        end
                      end
                      
                      div style: "font-size: 11px; text-align: center;" do
                        div truncate(attachment.filename.to_s, length: 15)
                        div "#{number_to_human_size(attachment.byte_size)}", style: "color: #666;"
                      end
                      
                      div style: "text-align: center; margin-top: 5px;" do
                        link_to "下载", rails_blob_path(attachment, disposition: "attachment"),
                                class: "button small", style: "font-size: 10px; padding: 2px 6px;"
                      end
                    end
                  end
                  
                  if fd.attachment_count > 3
                    div style: "display: flex; align-items: center; color: #666; font-size: 12px;" do
                      "还有 #{fd.attachment_count - 3} 个附件..."
                    end
                  end
                end
              end
              column "附件统计" do |fd|
                div do
                  strong "#{fd.attachment_count}个文件"
                  br
                  span "#{number_to_human_size(fd.attachment_total_size)}"
                  br
                  small fd.attachment_types_summary, style: "color: #666;"
                end
              end
            end
          else
            para "该报销单暂无附件", style: "text-align: center; color: #999; padding: 40px;"
          end
        end
      end
    end
    
  end

  # 表单页
  form do |f|
    f.inputs "报销单信息" do
      f.input :invoice_number, input_html: { readonly: !f.object.new_record? }
      f.input :document_name
      f.input :applicant
      f.input :applicant_id
      f.input :company
      f.input :department
      f.input :amount, min: 0.01
      f.input :status, label: "内部状态", as: :select, collection: Reimbursement.state_machines[:status].states.map(&:value), include_blank: false
      f.input :external_status, label: "外部状态", as: :select,
  collection: ["审批中", "已付款", "待付款", "待审核"],
  include_blank: false
      f.input :receipt_status, as: :select, collection: ["pending", "received"]
      f.input :receipt_date, as: :datepicker
      f.input :submission_date, as: :datepicker
      f.input :is_electronic
      f.input :approval_date, as: :datepicker
      f.input :approver_name
      f.input :related_application_number
      f.input :accounting_date, as: :datepicker
      f.input :document_tags
    end
    
    f.inputs "手动覆盖状态信息", class: "manual-override-info" do
      f.input :manual_override, label: "手动覆盖状态", input_html: { readonly: true }
      f.input :manual_override_at, label: "手动覆盖时间", input_html: { readonly: true }
      f.input :last_external_status, label: "最后外部状态", input_html: { readonly: true }
      f.li "注意：手动覆盖字段为只读，请使用页面上的手动控制按钮进行修改", class: "manual-override-note"
    end
    
    f.inputs "ERP 系统字段" do
      f.input :erp_current_approval_node
      f.input :erp_current_approver
      f.input :erp_flexible_field_2
      f.input :erp_node_entry_time, as: :datepicker
      f.input :erp_first_submitted_at, as: :datepicker
      f.input :erp_flexible_field_8
    end
    
    f.actions
  end

  # Existing member_action :close (used by "处理完成" button)
  member_action :close, method: :put do
    begin
      resource.close_processing!
      redirect_to admin_reimbursement_path(resource), notice: "报销单已关闭 (处理完成)"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_reimbursement_path(resource), alert: "操作失败: #{e.message}"
    rescue => e
      redirect_to admin_reimbursement_path(resource), alert: "发生未知错误: #{e.message}"
    end
  end

  # ADDED: member_action :reopen_reimbursement
  member_action :reopen_reimbursement, method: :put do
    begin
      resource.reopen_to_processing!
      redirect_to admin_reimbursement_path(resource), notice: "报销单已取消完成，状态恢复为处理中。"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_reimbursement_path(resource), alert: "操作失败: #{e.message}"
    rescue => e
      redirect_to admin_reimbursement_path(resource), alert: "发生未知错误: #{e.message}"
    end
  end

  # Manual Override Controls - 手动状态覆盖控制
  member_action :manual_set_pending, method: :put do
    command = Commands::SetReimbursementStatusCommand.new(
      reimbursement_id: resource.id,
      status: 'pending',
      current_user: current_admin_user
    )

    result = command.call

    if result.success?
      redirect_to admin_reimbursement_path(resource), notice: result.message
    else
      redirect_to admin_reimbursement_path(resource), alert: result.message
    end
  end

  member_action :manual_set_processing, method: :put do
    command = Commands::SetReimbursementStatusCommand.new(
      reimbursement_id: resource.id,
      status: 'processing',
      current_user: current_admin_user
    )

    result = command.call

    if result.success?
      redirect_to admin_reimbursement_path(resource), notice: result.message
    else
      redirect_to admin_reimbursement_path(resource), alert: result.message
    end
  end

  member_action :manual_set_closed, method: :put do
    command = Commands::SetReimbursementStatusCommand.new(
      reimbursement_id: resource.id,
      status: 'closed',
      current_user: current_admin_user
    )

    result = command.call

    if result.success?
      redirect_to admin_reimbursement_path(resource), notice: result.message
    else
      redirect_to admin_reimbursement_path(resource), alert: result.message
    end
  end

  member_action :reset_manual_override, method: :put do
    command = Commands::ResetReimbursementOverrideCommand.new(
      reimbursement_id: resource.id,
      current_user: current_admin_user
    )

    result = command.call

    if result.success?
      redirect_to admin_reimbursement_path(resource), notice: result.message
    else
      redirect_to admin_reimbursement_path(resource), alert: result.message
    end
  end
  
  # 报销单分配相关的成员操作 - 直接进行权限检查
  member_action :assign, method: :post do
    unless current_admin_user.super_admin?
      redirect_to admin_reimbursement_path(resource), alert: '您没有权限执行分配操作，请联系超级管理员'
      return
    end

    command = Commands::AssignReimbursementCommand.new(
      reimbursement_id: resource.id,
      assignee_id: params[:assignee_id],
      notes: params[:notes],
      current_user: current_admin_user
    )

    result = command.call

    if result.success?
      assignment = result.data
      redirect_to admin_reimbursement_path(resource), notice: "报销单已分配给 #{assignment.assignee.email}"
    else
      redirect_to admin_reimbursement_path(resource), alert: "报销单分配失败: #{result.message}"
    end
  end
  
  member_action :transfer_assignment, method: :post do
    policy = ReimbursementPolicy.new(current_admin_user)
    unless policy.can_transfer_assignment?
      redirect_to admin_reimbursement_path(resource), alert: policy.authorization_error_message(action: :transfer_assignment)
      return
    end
    
    service = ReimbursementAssignmentService.new(current_admin_user)
    assignment = service.transfer(resource.id, params[:assignee_id], params[:notes])
    
    if assignment
      redirect_to admin_reimbursement_path(resource), notice: "报销单已转移给 #{assignment.assignee.email}"
    else
      redirect_to admin_reimbursement_path(resource), alert: "报销单转移失败"
    end
  end
  
  member_action :unassign, method: :post do
    policy = ReimbursementPolicy.new(current_admin_user)
    unless policy.can_unassign?
      redirect_to admin_reimbursement_path(resource), alert: policy.authorization_error_message(action: :unassign)
      return
    end
    
    if resource.active_assignment.present?
      service = ReimbursementAssignmentService.new(current_admin_user)
      if service.unassign(resource.active_assignment.id)
        redirect_to admin_reimbursement_path(resource), notice: "报销单分配已取消"
      else
        redirect_to admin_reimbursement_path(resource), alert: "报销单取消分配失败"
      end
    else
      redirect_to admin_reimbursement_path(resource), alert: "报销单当前没有活跃的分配"
    end
  end
  
  
  # 快速分配 - 直接进行权限检查
  collection_action :quick_assign, method: :post do
    policy = ReimbursementPolicy.new(current_admin_user)
    unless policy.can_assign?
      redirect_to admin_dashboard_path, alert: policy.authorization_error_message(action: :assign)
      return
    end
    
    if params[:reimbursement_id].blank?
      redirect_to admin_dashboard_path, alert: "请选择要分配的报销单"
      return
    end
    
    if params[:assignee_id].blank?
      redirect_to admin_dashboard_path, alert: "请选择审核人员"
      return
    end
    
    service = ReimbursementAssignmentService.new(current_admin_user)
    assignment = service.assign(params[:reimbursement_id], params[:assignee_id], params[:notes])
    
    if assignment
      redirect_to admin_reimbursement_path(assignment.reimbursement),
                  notice: "报销单 #{assignment.reimbursement.invoice_number} 已分配给 #{assignment.assignee.email}"
    else
      redirect_to admin_dashboard_path, alert: "报销单分配失败"
    end
  end
  
  # 定义路由辅助方法
  collection_action :quick_assign_path, method: :get do
    render json: { path: collection_path(action: :quick_assign) }
  end
  
end
