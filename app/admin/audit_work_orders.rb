ActiveAdmin.register AuditWorkOrder do
  permit_params :reimbursement_id, :audit_comment, # resolution & audit_date are set by system, creator_id by controller
                :vat_verified,
                # 共享字段 - 使用 _id 后缀
                :problem_type_id, :problem_description_id, :remark, :processing_opinion,
                submitted_fee_detail_ids: []
  # 移除 status 从 permit_params 中，状态由系统自动管理

  menu priority: 4, label: "审核工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'
  config.remove_action_item :new

  controller do
    def scoped_collection
      AuditWorkOrder.includes(:reimbursement, :creator, :fee_details) # 预加载更多关联
    end

    # 创建时设置报销单ID
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # 如果是从表单提交的，设置 submitted_fee_detail_ids
      if params[:audit_work_order] && params[:audit_work_order][:submitted_fee_detail_ids] # Changed from :fee_detail_ids
        # 添加调试日志
        Rails.logger.debug "AuditWorkOrder build_new_resource: 设置 submitted_fee_detail_ids 为 #{params[:audit_work_order][:submitted_fee_detail_ids].inspect}"
        resource.submitted_fee_detail_ids = params[:audit_work_order][:submitted_fee_detail_ids] # Changed from :fee_detail_ids
        # 检查设置后的值
        Rails.logger.debug "AuditWorkOrder build_new_resource: 设置后 submitted_fee_detail_ids 为 #{resource.submitted_fee_detail_ids.inspect}"
      else
        Rails.logger.debug "AuditWorkOrder build_new_resource: 没有 submitted_fee_detail_ids 参数"
      end
      resource
    end
    
    # Updated create action
    def create
      # Permit submitted_fee_detail_ids along with other attributes
      # Parameters should align with the main permit_params, using _id for problem type/description
      _audit_work_order_params = params.require(:audit_work_order).permit(
        :reimbursement_id, :audit_comment, # resolution & audit_date are set by system
        :problem_type_id, :problem_description_id, :remark, :processing_opinion,
        submitted_fee_detail_ids: [] 
      )

      @audit_work_order = AuditWorkOrder.new(_audit_work_order_params.except(:submitted_fee_detail_ids))
      @audit_work_order.creator_id = current_admin_user.id # Set creator

      if _audit_work_order_params[:submitted_fee_detail_ids].present?
        @audit_work_order.submitted_fee_detail_ids = _audit_work_order_params[:submitted_fee_detail_ids]
      end
      
      if @audit_work_order.save
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: "审核工单已成功创建"
      else
        # Re-fetch reimbursement if save fails, needed for the form on render :new
        @reimbursement = Reimbursement.find_by(id: _audit_work_order_params[:reimbursement_id])
        # 保留已选择的费用明细
        @audit_work_order.submitted_fee_detail_ids = _audit_work_order_params[:submitted_fee_detail_ids] if _audit_work_order_params[:submitted_fee_detail_ids].present?
        flash.now[:error] = "创建审核工单失败: #{@audit_work_order.errors.full_messages.join(', ')}"
        render :new
      end
    end

    # Update action might need review if fee details were editable here before
    def update
      @audit_work_order = AuditWorkOrder.find(params[:id])
      service = AuditWorkOrderService.new(@audit_work_order, current_admin_user)
      
      # Use the centrally defined audit_work_order_params method for strong parameters
      if service.update(audit_work_order_params_for_update) # Renamed to avoid conflict if audit_work_order_params is used elsewhere by AA
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: '审核工单已更新'
      else
        render :edit
      end
    end

    private
    
    # Renamed to audit_work_order_params_for_update to be specific for the update action context
    def audit_work_order_params_for_update 
      params.require(:audit_work_order).permit(
        :processing_opinion,
        :problem_type_id,         # Use _id
        :problem_description_id,  # Use _id
        :audit_comment,
        :remark,
        submitted_fee_detail_ids: []  # If editable
      )
    end
  end

  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: -> { AuditWorkOrder.state_machine(:status).states.map(&:value) }
  filter :creator # 过滤创建人
  filter :created_at

  # 批量操作
  batch_action :start_processing, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
    batch_action_collection.find(ids).each do |work_order|
      begin
        AuditWorkOrderService.new(work_order, current_admin_user).start_processing
      rescue => e
         Rails.logger.warn "Batch action start_processing failed for AuditWorkOrder #{work_order.id}: #{e.message}"
      end
    end
    redirect_to collection_path, notice: "已尝试将选中的工单标记为处理中"
  end

  # 范围过滤器
  scope :all, default: true
  scope :pending
  scope :processing
  scope :approved
  scope :rejected

  # 操作按钮 - 更新为支持直接通过路径
  action_item :start_processing, only: :show, if: proc { resource.pending? && !resource.completed? } do
    link_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :post, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :approve, only: :show, if: proc { (resource.pending? || resource.processing?) && !resource.completed? } do
    link_to "审核通过", approve_admin_audit_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? && !resource.completed? } do
    link_to "审核拒绝", reject_admin_audit_work_order_path(resource)
  end
  action_item :mark_as_complete, only: :show, if: proc { (resource.status == 'approved' || resource.status == 'rejected') && !resource.completed? } do
    link_to "审核完成", mark_as_complete_admin_audit_work_order_path(resource), method: :post, data: { confirm: "确定要将此工单标记为完成吗？此操作将锁定工单。" }
  end
  action_item :delete_reimbursement, only: :show, priority: 3, if: proc { !resource.completed? } do
    link_to "删除报销单", admin_reimbursement_path(resource.reimbursement),
            method: :delete,
            data: { confirm: "确定要删除此报销单吗？此操作将删除所有相关联的工单。" }
  end

  # 成员操作
  member_action :start_processing, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.start_processing
      redirect_to admin_audit_work_order_path(resource), notice: "工单已开始处理"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :approve, method: :get do
    redirect_to admin_audit_work_order_path(resource), alert: "工单已完成，无法操作。" if resource.completed?
    @audit_work_order = resource
    render :approve # 渲染 app/views/admin/audit_work_orders/approve.html.erb
  end

  member_action :do_approve, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    # Permit only relevant fields for approve action, assuming form only has audit_comment
    # If problem_type_id etc. are on this form, add them here.
    permitted_params = params.require(:audit_work_order).permit(:audit_comment, :processing_opinion) # processing_opinion might also be set if form allows
    if service.approve(permitted_params)
      redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
    else
      @audit_work_order = resource # 重新赋值用于表单渲染
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    redirect_to admin_audit_work_order_path(resource), alert: "工单已完成，无法操作。" if resource.completed?
    @audit_work_order = resource
    render :reject # 渲染 app/views/admin/audit_work_orders/reject.html.erb
  end

  member_action :do_reject, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    # Permit relevant fields for reject action
    permitted_params = params.require(:audit_work_order).permit(
      :audit_comment, 
      :problem_type_id,           # Use _id
      :problem_description_id,    # Use _id
      :remark, 
      :processing_opinion
    )
    if service.reject(permitted_params)
      redirect_to admin_audit_work_order_path(resource), notice: "审核已拒绝"
    else
       @audit_work_order = resource # 重新赋值用于表单渲染
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :reject
    end
  end

  member_action :verify_fee_detail, method: :get do
     @work_order = resource
     # 使用新的关联查找 fee_detail
     @fee_detail = @work_order.fee_details.find_by(id: params[:fee_detail_id])
     unless @fee_detail
       redirect_to admin_audit_work_order_path(@work_order), alert: "未找到关联的费用明细 ##{params[:fee_detail_id]}"
       return
     end
     render 'admin/shared/verify_fee_detail'
  end

  member_action :do_verify_fee_detail, method: :post do
    @work_order = resource # Assign resource to @work_order for consistency
    service = AuditWorkOrderService.new(@work_order, current_admin_user) # Use @work_order

    # 查找 fee_detail 以便在失败时重新渲染表单
    @fee_detail = @work_order.fee_details.find_by(id: params[:fee_detail_id])
    unless @fee_detail
      redirect_to admin_audit_work_order_path(@work_order), alert: "尝试验证的费用明细 ##{params[:fee_detail_id]} 未找到或未关联。"
      return
    end

    if service.update_fee_detail_verification(params[:fee_detail_id], params[:verification_status], params[:comment])
       redirect_to admin_audit_work_order_path(@work_order), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
    else
       # Errors should be on @work_order.errors from the service call if it added them,
       # or on @fee_detail.errors if FeeDetailVerificationService added them.
       # Ensure verify_fee_detail.html.erb can display errors from @work_order or @fee_detail
       flash.now[:alert] = "费用明细 ##{params[:fee_detail_id]} 更新失败。"
       # Add specific errors to flash or ensure they are on @work_order.errors or @fee_detail.errors
       # Example: @work_order.errors.full_messages.join(', ')
       # Example: @fee_detail.errors.full_messages.join(', ')
       render 'admin/shared/verify_fee_detail'
    end
  end

  member_action :mark_as_complete, method: :post do
    if resource.completed?
      redirect_to admin_audit_work_order_path(resource), alert: "此工单已标记为完成。"
    elsif resource.status == 'approved' || resource.status == 'rejected'
      if resource.update(completed: true)
        redirect_to admin_audit_work_order_path(resource), notice: "工单已成功标记为完成。"
      else
        redirect_to admin_audit_work_order_path(resource), alert: "标记完成失败: #{resource.errors.full_messages.join(', ')}"
      end
    else
      redirect_to admin_audit_work_order_path(resource), alert: "只有状态为 Approved 或 Rejected 的工单才能标记为完成。"
    end
  end

  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :status do |wo| status_tag wo.status end
    column :problem_type
    column :creator
    column :created_at
    actions do |work_order|
      item "查看", admin_audit_work_order_path(work_order)
      unless work_order.completed?
        item "编辑", edit_admin_audit_work_order_path(work_order), class: "member_link edit_link"
        item "删除", admin_audit_work_order_path(work_order), method: :delete, data: { confirm: "确定要删除吗?" }, class: "member_link delete_link"
      end
    end
  end

  # 详情页
  show title: proc{|wo| "审核工单 ##{wo.id}" } do
    panel "基本信息" do
      # reimbursement display partial (原"基本信息"Tab内容)
      if resource.reimbursement.present?
        render 'admin/reimbursements/reimbursement_display', reimbursement: resource.reimbursement
      end

      # attributes_table (原"基本信息"Tab内容)
      attributes_table do
        row :id
        row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
        row :type
        row :status do |wo| status_tag wo.status end
        row :completed do |wo|
          status_tag wo.completed? ? '是' : '否', class: (wo.completed? ? :ok : :warn)
        end
        row :audit_comment
        row :audit_date
        row :vat_verified
        # 显示共享字段 (Req 6/7)
        row :problem_type
        row :problem_description
        row :remark
        row :processing_opinion
        row :creator
        row :created_at
        row :updated_at
      end
    end

    # panel for Fee Details (原"费用明细"Tab内容)
    panel "关联的费用明细" do
      table_for audit_work_order.fee_details do
        column "ID" do |fee_detail|
          link_to fee_detail.id, admin_fee_detail_path(fee_detail)
        end
        column "费用类型", :fee_type
        column "金额" do |fee_detail|
          number_to_currency(fee_detail.amount, unit: fee_detail.currency)
        end
        column "费用日期", :fee_date
        column "备注", :notes
        column "创建时间", :created_at
        column "更新时间", :updated_at
      end
    end
  end

  # 表单使用 partial
  form title: proc { |wo| wo.new_record? ? "新建审核工单" : (wo.completed? ? "查看已完成审核工单 ##{wo.id}" : "编辑审核工单 ##{wo.id}") } do |f|
    if f.object.completed?
      panel "工单已完成" do
        para "此工单已标记为完成，无法编辑。"
      end
    else
      f.semantic_errors

      reimbursement = f.object.reimbursement || (params[:reimbursement_id] ? Reimbursement.find_by(id: params[:reimbursement_id]) : nil)

      tabs do
        tab '基本信息' do
          f.inputs '工单详情' do
            if reimbursement
              f.input :reimbursement_id, as: :hidden, input_html: { value: reimbursement.id }
              f.input :reimbursement_invoice_number, label: '报销单号', input_html: { value: reimbursement.invoice_number, readonly: true, disabled: true }
            elsif f.object.reimbursement
               f.input :reimbursement_invoice_number, label: '报销单号', input_html: { value: f.object.reimbursement.invoice_number, readonly: true, disabled: true }
            end
            f.input :status, input_html: { readonly: true, disabled: true }, label: '工单状态' if f.object.persisted?
          end

          # Updated Fee Detail Section
          if reimbursement
            render 'admin/shared/fee_details_selection', work_order: f.object, reimbursement: reimbursement
          else
            f.inputs '费用明细' do
              para "无法加载费用明细，未关联有效的报销单。"
            end
          end

          f.inputs '处理与反馈' do
            f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all, include_blank: '请选择处理意见', input_html: { id: 'audit_work_order_processing_opinion' }
            
            f.input :problem_type_id, as: :select, collection: ProblemType.all.map { |pt| [pt.name, pt.id] }, include_blank: '请选择问题类型', wrapper_html: { id: 'problem_type_row', style: 'display:none;' }
            
            f.input :problem_description_id, as: :select, collection: ProblemDescription.all.map { |pd| [pd.description, pd.id] }, include_blank: '请选择问题描述', wrapper_html: { id: 'problem_description_row', style: 'display:none;' }
            
            f.input :audit_comment, label: "审核意见", wrapper_html: { id: 'audit_comment_row', style: 'display:none;' }
            
            f.input :remark, label: "备注", wrapper_html: { id: 'remark_row', style: 'display:none;' }
          end
        end
      end
      f.actions

      # JavaScript for conditional fields
      script do
        raw """
          document.addEventListener('DOMContentLoaded', function() {
            const processingOpinionSelect = document.getElementById('audit_work_order_processing_opinion');
            const problemTypeRow = document.getElementById('problem_type_row');
            const problemDescriptionRow = document.getElementById('problem_description_row');
            const auditCommentRow = document.getElementById('audit_comment_row');
            const remarkRow = document.getElementById('remark_row');

            function toggleFields() {
              if (!processingOpinionSelect || !problemTypeRow || !problemDescriptionRow || !auditCommentRow || !remarkRow) {
                return;
              }
              const selectedValue = processingOpinionSelect.value;

              problemTypeRow.style.display = 'none';
              problemDescriptionRow.style.display = 'none';
              auditCommentRow.style.display = 'none';
              remarkRow.style.display = 'none';

              if (selectedValue === '无法通过') {
                problemTypeRow.style.display = 'list-item';
                problemDescriptionRow.style.display = 'list-item';
                auditCommentRow.style.display = 'list-item';
                remarkRow.style.display = 'list-item';
              } else if (selectedValue === '可以通过') {
                auditCommentRow.style.display = 'list-item';
              } else { // Blank
                auditCommentRow.style.display = 'list-item';
              }
            }

            if (processingOpinionSelect) {
              processingOpinionSelect.addEventListener('change', toggleFields);
              toggleFields();
            }
          });
        """
      end
    end
  end
  
  # 处理意见与状态关系由模型的 set_status_based_on_processing_opinion 回调自动处理
  
  # 移除控制器方法处理处理意见与状态关系
  # 处理意见与状态的关系由模型的 set_status_based_on_processing_opinion 回调自动处理
end