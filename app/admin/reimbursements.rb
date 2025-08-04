ActiveAdmin.register Reimbursement do
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
      resource.mark_all_as_viewed!
      super
    end
    
    private
    
    # 确保scope计数和数据显示的正确逻辑
    def scoped_collection
      # 如果是查看单个报销单（show action），则不应用任何scope，直接返回所有报销单
      # 这样可以确保即使报销单未分配给当前用户，也能通过ID查看到
      if params[:id].present?
        return end_of_association_chain
      end

      # 获取当前选择的scope和用户角色
      current_scope = params[:scope]
      is_super_admin = current_admin_user.super_admin?
      
      # 根据不同的scope和用户角色应用相应的过滤器
      case current_scope
      when 'assigned_to_me', 'my_assignments'
        # "分配给我的"或"我的报销单"scope - 显示分配给当前用户的报销单
        # 对所有角色都一样
        end_of_association_chain.assigned_to_user(current_admin_user.id)
      when 'pending'
        if is_super_admin
          # 超级管理员可以看到所有待处理的报销单
          end_of_association_chain.where(status: 'pending')
        else
          # 普通管理员只能看到分配给自己的待处理报销单
          end_of_association_chain.assigned_to_user(current_admin_user.id).where(status: 'pending')
        end
      when 'processing'
        if is_super_admin
          # 超级管理员可以看到所有处理中的报销单
          end_of_association_chain.where(status: 'processing')
        else
          # 普通管理员只能看到分配给自己的处理中报销单
          end_of_association_chain.assigned_to_user(current_admin_user.id).where(status: 'processing')
        end
      when 'closed'
        if is_super_admin
          # 超级管理员可以看到所有已关闭的报销单
          end_of_association_chain.where(status: 'closed')
        else
          # 普通管理员只能看到分配给自己的已关闭报销单
          end_of_association_chain.assigned_to_user(current_admin_user.id).where(status: 'closed')
        end
      when 'unassigned'
        # "未分配的"scope - 显示未分配的报销单
        # 所有角色都可以看到，但只有超级管理员可以分配（这在批量操作中控制）
        end_of_association_chain.left_joins(:active_assignment).where(reimbursement_assignments: { id: nil }, status: 'pending')
      when nil, ''
        # 空scope参数默认到"分配给我的"
        end_of_association_chain.assigned_to_user(current_admin_user.id)
      when 'all'
        # "全部"scope - 显示所有数据，不考虑角色
        end_of_association_chain
      else
        # 其他scope - 显示所有数据
        end_of_association_chain
      end
    end
  end

  # 过滤器
  filter :invoice_number
  filter :applicant
  filter :company, label: "公司", as: :string
  filter :department, label: "部门", as: :string
  filter :status, label: "内部状态", as: :select, collection: Reimbursement.state_machines[:status].states.map(&:value)
  filter :external_status, label: "外部状态", as: :select, collection: ["审批中", "已付款", "代付款", "待审核"]
  filter :receipt_status, as: :select, collection: ["pending", "received"]
  filter :is_electronic, as: :boolean
  filter :document_tags, label: "单据标签", as: :string
  filter :created_at
  filter :approval_date
  filter :current_assignee_id, as: :select, collection: -> { AdminUser.all.map { |u| [u.email, u.id] } }, label: "当前处理人"
  filter :with_unviewed_records, label: '有新通知', as: :boolean

  # 列表页范围过滤器 - 使用标准ActiveRecord scope确保计数一致性
  scope :all, label: "全部", show_count: false
  
  # 定义"分配给我的"为默认scope
  scope "分配给我的", :assigned_to_me, default: true, show_count: false do |reimbursements|
    reimbursements.assigned_to_user(current_admin_user.id)
  end
  
  # 为了兼容性，添加my_assignments作为assigned_to_me的别名
  scope "我的报销单", :my_assignments, show_count: false do |reimbursements|
    reimbursements.assigned_to_user(current_admin_user.id)
  end
  
  scope :pending, label: "待处理", show_count: false do |reimbursements|
    reimbursements.where(status: 'pending')
  end
  
  scope :processing, label: "处理中", show_count: false do |reimbursements|
    reimbursements.where(status: 'processing')
  end
  
  scope :closed, label: "已关闭", show_count: false do |reimbursements|
    reimbursements.where(status: 'closed')
  end
  
  scope :unassigned, label: "未分配的", show_count: false do |reimbursements|
    reimbursements.left_joins(:active_assignment).where(reimbursement_assignments: { id: nil }, status: 'pending')
  end
  
  # 添加有新通知的scope
  scope "有新通知", :with_unviewed_records, show_count: false do |reimbursements|
    reimbursements.with_unviewed_records
  end

  # 批量操作
  batch_action :mark_as_received do |ids|
     batch_action_collection.find(ids).each do |reimbursement|
        reimbursement.update(receipt_status: 'received', receipt_date: Time.current)
     end
     redirect_to collection_path, notice: "已将选中的报销单标记为已收单"
  end
  batch_action :start_processing, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
     batch_action_collection.find(ids).each do |reimbursement|
        begin
          reimbursement.start_processing!
        rescue StateMachines::InvalidTransition => e
          Rails.logger.warn "Batch action start_processing failed for Reimbursement #{reimbursement.id}: #{e.message}"
        end
     end
     redirect_to collection_path, notice: "已尝试将选中的报销单标记为处理中"
  end
  
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
      assignee: AdminUser.all.map { |u| [u.email, u.id] },
      notes: :text
    }
  } do |ids, inputs|
    unless current_admin_user.super_admin?
      redirect_to collection_path, alert: '您没有权限执行分配操作，请联系超级管理员'
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
  
  action_item :batch_assign, only: :index, if: proc {
    true # 总是显示，但根据权限决定是否禁用
  } do
    css_class = current_admin_user.super_admin? ? "button" : "button disabled_action"
    title = current_admin_user.super_admin? ? nil : '您没有权限执行分配操作，请联系超级管理员'
    
    link_to "批量分配报销单",
            collection_path(action: :batch_assign),
            class: css_class,
            title: title
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

  # 导入操作
  collection_action :new_import, method: :get do
    render "admin/shared/import_form", locals: {
      title: "导入报销单",
      import_path: import_admin_reimbursements_path,
      cancel_path: admin_reimbursements_path,
      instructions: [
        "请上传CSV格式文件",
        "文件必须包含以下列：报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,收单状态,收单日期,关联申请单号,提交报销日期,记账日期,报销单状态 (此列的值将导入到外部状态字段),当前审批节点,当前审批人,报销单审核通过日期,审核通过人,报销金额（单据币种）,弹性字段2,当前审批节点转入时间,首次提交时间,单据标签,弹性字段8",
        "如果报销单已存在（根据报销单单号判断），将更新现有记录",
        "如果报销单不存在，将创建新记录"
      ]
    }
  end

  collection_action :import, method: :post do
    # 确保文件参数存在
    unless params[:file].present?
       redirect_to new_import_admin_reimbursements_path, alert: "请选择要导入的文件。"
       return
    end
    service = ReimbursementImportService.new(params[:file], current_admin_user)
    result = service.import
    if result[:success]
      notice_message = "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新."
      notice_message += " #{result[:errors]} 错误." if result[:errors].to_i > 0
      redirect_to admin_reimbursements_path, notice: notice_message
    else
      alert_message = "导入失败: #{result[:error_details] ? result[:error_details].join(', ') : result[:errors]}"
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

  # 列表页
  index do
    # 添加角色和权限提示信息
    div class: "role_notice_panel" do
      role_display = case current_admin_user.role
                     when 'admin'
                       '普通管理员'
                     when 'super_admin'
                       '超级管理员'
                     else
                       '未知角色'
                     end
      
      div class: "role_info" do
        span "当前角色: #{role_display}", class: "role_badge"
      end
      
      unless current_admin_user.super_admin?
        div class: "permission_notice" do
          span '您没有权限执行分配操作，请联系超级管理员', class: "warning_text"
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
    column :erp_current_approval_node, label: "当前审批节点" do |reimbursement|
      reimbursement.erp_current_approval_node || '0'
    end
    column :erp_node_entry_time, label: "当前审批节点转入时间" do |reimbursement|
      reimbursement.erp_node_entry_time&.strftime('%Y-%m-%d %H:%M:%S') || '0'
    end
    column :approval_date, label: "报销单审核通过日期" do |reimbursement|
      reimbursement.approval_date&.strftime('%Y-%m-%d %H:%M:%S') || '0'
    end
    column "内部状态", :status do |reimbursement| 
      status_tag reimbursement.status.upcase
    end
    column :current_assignee, label: "Current Assignee" do |reimbursement|
      reimbursement.current_assignee&.email || "未分配"
    end
    column "通知状态", :sortable => false do |reimbursement|
      span do
        if reimbursement.has_unviewed_express_receipts?
          status_tag "+快", class: "warning" # 使用现有的warning样式（橙色）
        end
        
        if reimbursement.has_unviewed_operation_histories?
          status_tag "+记", class: "error" # 使用现有的error样式（红色）
        end
        
        unless reimbursement.has_unviewed_records?
          status_tag "--", class: "completed" # 使用现有的completed样式（绿色）
        end
      end
    end
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
          table_for resource.fee_details.includes(:work_orders).order(created_at: :desc) do
            column(:id) { |fd| link_to fd.id, admin_fee_detail_path(fd) }
            column :fee_type
            column "金额", :amount do |fd| number_to_currency(fd.amount, unit: "¥") end
            column "验证状态", :verification_status do |fd| status_tag fd.verification_status end
            column "关联工单" do |fee_detail|
              latest_wo = fee_detail.latest_associated_work_order
              if latest_wo
                link_to "##{latest_wo.id}", [:admin, latest_wo]
              else
                "无"
              end
            end
            column "问题类型" do |fee_detail|
              latest_wo = fee_detail.latest_associated_work_order
              if latest_wo && latest_wo.problem_types.any?
                problem_details = latest_wo.problem_types.map do |problem_type|
                  "#{problem_type.code}-#{problem_type.title}-#{problem_type.sop_description}+#{problem_type.standard_handling}"
                end.join("\n")
                
                content_tag(:pre, problem_details,
                  class: "problem-type-plain-text",
                  style: "white-space: pre-wrap; margin: 0; font-family: monospace; font-size: 12px;")
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
            column "问题详情" do |work_order|
              if work_order.problem_types.any?
                problem_details = work_order.problem_types.map do |problem_type|
                  [
                    "工单号: ##{work_order.id}",
                    "问题类型: #{problem_type.code}",
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
  collection: ["审批中", "已付款", "代付款", "待审核"],
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
  
  # 报销单分配相关的成员操作 - 直接进行权限检查
  member_action :assign, method: :post do
    unless current_admin_user.super_admin?
      redirect_to admin_reimbursement_path(resource), alert: '您没有权限执行分配操作，请联系超级管理员'
      return
    end
    
    service = ReimbursementAssignmentService.new(current_admin_user)
    assignment = service.assign(resource.id, params[:assignee_id], params[:notes])
    
    if assignment
      redirect_to admin_reimbursement_path(resource), notice: "报销单已分配给 #{assignment.assignee.email}"
    else
      redirect_to admin_reimbursement_path(resource), alert: "报销单分配失败"
    end
  end
  
  member_action :transfer_assignment, method: :post do
    unless current_admin_user.super_admin?
      redirect_to admin_reimbursement_path(resource), alert: '您没有权限执行分配操作，请联系超级管理员'
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
    unless current_admin_user.super_admin?
      redirect_to admin_reimbursement_path(resource), alert: '您没有权限执行分配操作，请联系超级管理员'
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
  
  # 批量分配相关的集合操作 - 直接进行权限检查
  collection_action :batch_assign, method: :get do
    # 获取未分配的报销单
    @reimbursements = Reimbursement.left_joins(:active_assignment)
                                  .where(reimbursement_assignments: { id: nil })
                                  .order(created_at: :desc)
    
    render "admin/reimbursements/batch_assign"
  end
  
  collection_action :batch_assign, method: :post do
    unless current_admin_user.super_admin?
      redirect_to collection_path(action: :batch_assign), alert: '您没有权限执行分配操作，请联系超级管理员'
      return
    end
    
    if params[:reimbursement_ids].blank?
      redirect_to collection_path(action: :batch_assign), alert: "请选择要分配的报销单"
      return
    end
    
    if params[:assignee_id].blank?
      redirect_to collection_path(action: :batch_assign), alert: "请选择审核人员"
      return
    end
    
    service = ReimbursementAssignmentService.new(current_admin_user)
    results = service.batch_assign(params[:reimbursement_ids], params[:assignee_id], params[:notes])
    
    if results.any?
      redirect_to admin_reimbursements_path, notice: "成功分配 #{results.size} 个报销单给 #{AdminUser.find(params[:assignee_id]).email}"
    else
      redirect_to collection_path(action: :batch_assign), alert: "报销单分配失败"
    end
  end
  
  # 快速分配 - 直接进行权限检查
  collection_action :quick_assign, method: :post do
    unless current_admin_user.super_admin?
      redirect_to admin_dashboard_path, alert: '您没有权限执行分配操作，请联系超级管理员'
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