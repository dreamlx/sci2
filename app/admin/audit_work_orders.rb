ActiveAdmin.register AuditWorkOrder do
  permit_params :reimbursement_id, :audit_comment, # resolution & audit_date are set by system, creator_id by controller
                :vat_verified,
                # 共享字段 - 使用 _id 后缀
                :processing_opinion,
                submitted_fee_detail_ids: [], problem_type_ids: []
  # 移除 problem_type_id 从 permit_params 中，改为使用 problem_type_ids 数组
  # 移除 status 从 permit_params 中，状态由系统自动管理

  menu priority: 4, label: "审核工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'
  config.remove_action_item :new

  controller do
    before_action :set_current_admin_user_for_model

    def set_current_admin_user_for_model
      Current.admin_user = current_admin_user
    end

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
      # Parameters should align with the main permit_params, using _id for problem type
      _audit_work_order_params = params.require(:audit_work_order).permit(
        :reimbursement_id, :audit_comment, # resolution & audit_date are set by system
        :processing_opinion,
        submitted_fee_detail_ids: [], problem_type_ids: []
      )

      @audit_work_order = AuditWorkOrder.new(_audit_work_order_params.except(:submitted_fee_detail_ids, :problem_type_ids))
      @audit_work_order.created_by = current_admin_user.id # MODIFIED: Use created_by instead of creator_id

      if _audit_work_order_params[:submitted_fee_detail_ids].present?
        # Set the special instance variable for the callback in WorkOrder model
        @audit_work_order.instance_variable_set(:@_direct_submitted_fee_ids, _audit_work_order_params[:submitted_fee_detail_ids])
        # Also set the accessor for form repopulation if validation fails and we re-render new
        @audit_work_order.submitted_fee_detail_ids = _audit_work_order_params[:submitted_fee_detail_ids]
      end
      
      # 设置问题类型IDs
      if _audit_work_order_params[:problem_type_ids].present?
        @audit_work_order.problem_type_ids = _audit_work_order_params[:problem_type_ids]
      end
      
      if @audit_work_order.save
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: "审核工单已成功创建"
      else
        Rails.logger.debug "AuditWorkOrder save failed. Errors: #{@audit_work_order.errors.full_messages.inspect}" # DEBUG LINE
        # Re-fetch reimbursement if save fails, needed for the form on render :new
        @reimbursement = Reimbursement.find_by(id: _audit_work_order_params[:reimbursement_id])
        # Ensure @_direct_submitted_fee_ids is set for the callback if save is retried from a re-rendered form (though less likely)
        # and submitted_fee_detail_ids (accessor) is set for form repopulation.
        if _audit_work_order_params[:submitted_fee_detail_ids].present? 
          @audit_work_order.instance_variable_set(:@_direct_submitted_fee_ids, _audit_work_order_params[:submitted_fee_detail_ids])
          @audit_work_order.submitted_fee_detail_ids = _audit_work_order_params[:submitted_fee_detail_ids]
        end
        # 重新设置问题类型IDs
        if _audit_work_order_params[:problem_type_ids].present?
          @audit_work_order.problem_type_ids = _audit_work_order_params[:problem_type_ids]
        end
        flash.now[:error] = "创建审核工单失败: #{@audit_work_order.errors.full_messages.join(', ')}"
        render :new
      end
    end

    # Update action might need review if fee details were editable here before
    def update
      @audit_work_order = AuditWorkOrder.find(params[:id])
      service = AuditWorkOrderService.new(@audit_work_order, current_admin_user) # This service might be deprecated in favor of WorkOrderService
      
      update_params = audit_work_order_params_for_update
      if update_params[:submitted_fee_detail_ids].present?
        @audit_work_order.instance_variable_set(:@_direct_submitted_fee_ids, update_params[:submitted_fee_detail_ids])
        # For form repopulation on error, also set the accessor if it exists
        @audit_work_order.submitted_fee_detail_ids = update_params[:submitted_fee_detail_ids] if @audit_work_order.respond_to?(:submitted_fee_detail_ids=)
      end
      
      # 设置问题类型IDs
      if update_params[:problem_type_ids].present?
        @audit_work_order.problem_type_ids = update_params[:problem_type_ids]
      end

      # Use the centrally defined audit_work_order_params method for strong parameters
      # The service update method should ideally only take attributes for the model itself, not the fee IDs which are handled by callback
      if service.update(update_params.except(:submitted_fee_detail_ids, :problem_type_ids)) 
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: '审核工单已更新'
      else
        # If update fails, @_direct_submitted_fee_ids might need to be preserved or reset for the form
        # For now, assume submitted_fee_detail_ids accessor helps repopulate via the form builder if re-rendering edit
        render :edit
      end
    end

    private
    
    # Renamed to audit_work_order_params_for_update to be specific for the update action context
    def audit_work_order_params_for_update
      params.require(:audit_work_order).permit(
        :processing_opinion,
        :audit_comment,
        submitted_fee_detail_ids: [],
        problem_type_ids: []
      )
    end
  end

  # 过滤器 - Temporarily disabled to fix the "First argument in form cannot contain nil or be empty" error
  # filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  # filter :status, as: :select, collection: -> { AuditWorkOrder.state_machine(:status).states.map(&:value) }
  # filter :creator # 过滤创建人
  # filter :created_at
  
  # Disable filters completely
  config.filters = false

  # 批量操作
  # batch_action :start_processing, if: proc { params[:scope] == 'pending' || params[:q].blank? } do
  #   batch_action_collection.find(ids).each do |work_order|
  #     begin
  #       # Assuming WorkOrderService can now be used for AuditWorkOrder as well
  #       WorkOrderService.new(work_order, current_admin_user).start_processing # This method was removed
  #     rescue => e
  #       Rails.logger.warn "Batch action start_processing failed for AuditWorkOrder #{work_order.id}: #{e.message}"
  #     end
  #   end
  #   redirect_to collection_path, notice: "已尝试将选中的工单标记为处理中"
  # end

  # 范围过滤器
  scope :all, default: true
  scope :pending
  # scope :processing # REMOVED: 'processing' state and scope were removed from WorkOrder model
  scope :approved
  scope :rejected
  scope :completed

  # 操作按钮
  # REMOVED: start_processing action item as 'processing' state is removed
  # action_item :start_processing, only: :show, if: proc { resource.pending? && !resource.completed? } do
  #   link_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :put, data: { confirm: "确定要开始处理此工单吗?" }
  # end

  action_item :approve, only: :show, if: proc { resource.pending? } do
    link_to "审核通过", approve_admin_audit_work_order_path(resource) # Leads to a form
  end

  action_item :reject, only: :show, if: proc { resource.pending? } do
    link_to "审核拒绝", reject_admin_audit_work_order_path(resource) # Leads to a form
  end

  # REMOVED: new_audit_work_order action item (already present in Reimbursement show page)
  # action_item :new_audit_work_order, only: :show, if: proc{ !resource.reimbursement.closed? } do
  #   link_to "新建审核工单", new_admin_audit_work_order_path(reimbursement_id: resource.reimbursement.id)
  # end

  # REMOVED: new_communication_work_order action item (should be on Reimbursement show page or based on AuditWorkOrder context if needed)
  # action_item :new_communication_work_order, only: :show, if: proc{ !resource.reimbursement.closed? } do
  #   link_to "新建沟通工单", new_admin_communication_work_order_path(reimbursement_id: resource.reimbursement.id)
  # end

  # 自定义操作
  # REMOVED: start_processing member_action as 'processing' state is removed.
  # member_action :start_processing, method: :put do
  #   service = WorkOrderService.new(resource, current_admin_user) # Changed to WorkOrderService
  #   if service.start_processing # This method was removed
  #     redirect_to admin_audit_work_order_path(resource), notice: "工单已开始处理"
  #   else
  #     redirect_to admin_audit_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
  #   end
  # end

  member_action :approve, method: :get do
    redirect_to admin_audit_work_order_path(resource), alert: "工单已审核或已拒绝，无法再次操作。" if resource.approved? || resource.rejected?
    @audit_work_order = resource
    render :approve # 渲染 app/views/admin/audit_work_orders/approve.html.erb
  end

  member_action :do_approve, method: :post do
    # Use the base WorkOrderService
    service = WorkOrderService.new(resource, current_admin_user)
    # Params should align with what WorkOrderService and WorkOrder model expect
    # Ensure :processing_opinion is part of the permitted params for approval logic
    permitted_params = params.require(:audit_work_order).permit(
      :audit_comment, :processing_opinion,
      :vat_verified, # AuditWorkOrder specific, if still needed here
      problem_type_ids: []
    ).merge(processing_opinion: '可以通过') # Explicitly set for approval

    if service.approve(permitted_params)
      redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
    else
      @audit_work_order = resource # 重新赋值用于表单渲染
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    redirect_to admin_audit_work_order_path(resource), alert: "工单已审核或已拒绝，无法再次操作。" if resource.approved? || resource.rejected?
    @audit_work_order = resource
    render :reject # 渲染 app/views/admin/audit_work_orders/reject.html.erb
  end

  member_action :do_reject, method: :post do
    # Use the base WorkOrderService
    service = WorkOrderService.new(resource, current_admin_user)
    # Params should align with what WorkOrderService and WorkOrder model expect
    # Ensure :processing_opinion is part of the permitted params for rejection logic
    permitted_params = params.require(:audit_work_order).permit(
      :audit_comment, :processing_opinion,
      :vat_verified, # AuditWorkOrder specific, if still needed here
      problem_type_ids: []
    ).merge(processing_opinion: '无法通过') # Explicitly set for rejection

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
    # Use the base WorkOrderService for fee detail verification
    service = WorkOrderService.new(resource, current_admin_user)
    fee_detail_id = params[:fee_detail_id]
    verification_status = params[:verification_status]
    comment = params[:comment]

    if service.update_fee_detail_verification(fee_detail_id, verification_status, comment)
      redirect_to admin_audit_work_order_path(resource), notice: "费用明细 ##{fee_detail_id} 状态已更新"
    else
       # Errors should be on @work_order.errors from the service call if it added them,
       # or on @fee_detail.errors if FeeDetailVerificationService added them.
       # Ensure verify_fee_detail.html.erb can display errors from @work_order or @fee_detail
       flash.now[:alert] = "费用明细 ##{fee_detail_id} 更新失败。"
       # Add specific errors to flash or ensure they are on @work_order.errors or @fee_detail.errors
       # Example: @work_order.errors.full_messages.join(', ')
       # Example: @fee_detail.errors.full_messages.join(', ')
       render 'admin/shared/verify_fee_detail'
    end
  end

  # 列表页
  index do
    selectable_column
    id_column
    column "报销单号", :reimbursement do |wo|
      link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement)
    end
    column "处理意见", :processing_opinion do |wo|
      if wo.processing_opinion.present?
        status_class = case wo.processing_opinion
                       when '可以通过'
                         'ok'
                       when '无法通过'
                         'error'
                       else
                         'warning'
                       end
        status_tag wo.processing_opinion, class: status_class
      else
        span "未填写", class: "empty"
      end
    end
    column "费用明细", :fee_details do |wo|
      if wo.fee_details.any?
        wo.fee_details.map do |fd|
          link_to("##{fd.id}", admin_fee_detail_path(fd)) + " #{fd.fee_type} #{number_to_currency(fd.amount, unit: '¥')}"
        end.join("<br>").html_safe
      else
        "无费用明细"
      end
    end
    column "问题类型", :problem_types do |wo|
      if wo.problem_types.any?
        wo.problem_types.map { |pt| "#{pt.legacy_problem_code} - #{pt.title}" }.join(", ")
      else
        # 兼容旧数据
        wo.problem_type ? "#{wo.problem_type.legacy_problem_code} - #{wo.problem_type.title}" : nil
      end
    end
    column "创建人", :creator
    column "创建时间", :created_at
    column "操作" do |work_order|
      links = ActiveSupport::SafeBuffer.new
      links << link_to("查看", admin_audit_work_order_path(work_order), class: "member_link view_link")
      if work_order.editable? # Using new editable? logic from model
        links << link_to("编辑", edit_admin_audit_work_order_path(work_order), class: "member_link edit_link")
        links << link_to("删除", admin_audit_work_order_path(work_order), method: :delete, data: { confirm: "确定要删除吗?" }, class: "member_link delete_link")
      end
      links
    end
    
    div class: "action_items" do
      span class: "action_item" do
        link_to "导出CSV", export_csv_admin_audit_work_orders_path(q: params[:q]), class: "button"
      end
    end
  end

  collection_action :export_csv, method: :get do
    work_orders = AuditWorkOrder.includes(reimbursement: :fee_details)
      .ransack(params[:q]).result
      
    csv_data = CSV.generate(headers: true, force_quotes: true) do |csv|
      csv << ["ID", "报销单号", "处理意见", "审核结果", "问题类型", "创建人", "创建时间", "费用明细单号"]
      
      work_orders.find_each do |wo|
        problem_types = wo.problem_types.any? ?
          wo.problem_types.map { |pt| "#{pt.legacy_problem_code}-#{pt.title}" }.join(", ") :
          (wo.problem_type ? "#{wo.problem_type.legacy_problem_code}-#{wo.problem_type.title}" : "")
          
        document_numbers = wo.reimbursement&.fee_details&.pluck(:document_number)&.uniq&.join(", ") || ""
        
        csv << [
          wo.id,
          wo.reimbursement&.invoice_number,
          wo.processing_opinion,
          wo.status,
          problem_types,
          wo.creator&.email,
          wo.created_at,
          document_numbers
        ]
      end
    end
    
    send_data csv_data,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=审核工单_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
  end

  # 详情页
  show title: proc{|wo| "审核工单 ##{wo.id}" } do
    


      # attributes_table (原"基本信息"Tab内容)
      attributes_table do
        row :id
        row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
        row :type
        row :status do |wo| status_tag wo.status end
        row :audit_comment
        row :audit_date
        row :vat_verified
        row :creator
        row :created_at
        row :updated_at
      end
    
      # 工单相关信息专用显示区

    panel "问题类型" do
            # reimbursement display partial (原"基本信息"Tab内容)
      if resource.reimbursement.present?
        render 'admin/reimbursements/reimbursement_display', reimbursement: resource.reimbursement
      end
      if resource.problem_types.any?
        table_for resource.problem_types do
          column "编码", :code
          column "名称", :display_name
          column "问题描述" do |problem_type|
            "#{problem_type.sop_description} | #{problem_type.standard_handling}"
          end
          column "关联费用类型" do |problem_type|
            if problem_type.fee_type
              span do
                status_tag "已关联", class: "green"
                text_node " #{problem_type.fee_type.display_name}"
              end
            else
              status_tag "未关联费用类型", class: "orange"
            end
          end
        end
      else
        para "无问题类型"
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
          number_to_currency(fee_detail.amount, unit: "¥")
        end
        column "费用日期", :fee_date
        column "附件", :attachments do |fee_detail|
          if fee_detail.attachments.attached?
            div class: "attachment-summary" do
              span "📎 #{fee_detail.attachment_count}个文件",
                   style: "color: #2e8b57; font-weight: bold;"
              br
              small fee_detail.attachment_types_summary, style: "color: #666;"
            end
          else
            span "无附件", style: "color: #999;"
          end
        end
        column "备注", :notes
        column "创建时间", :created_at
        column "更新时间", :updated_at
      end
      # 操作记录面板

    end
          panel "操作记录" do
        if resource.operations.exists?
          table_for resource.operations.recent_first do
            column :id do |operation|
              link_to operation.id, admin_work_order_operation_path(operation)
            end
            column :operation_type do |operation|
              case operation.operation_type
              when WorkOrderOperation::OPERATION_TYPE_CREATE
                status_tag operation.operation_type_display, class: 'green'
              when WorkOrderOperation::OPERATION_TYPE_UPDATE
                status_tag operation.operation_type_display, class: 'orange'
              when WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE
                status_tag operation.operation_type_display, class: 'blue'
              when WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM
                status_tag operation.operation_type_display, class: 'green'
              when WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM
                status_tag operation.operation_type_display, class: 'red'
              when WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM
                status_tag operation.operation_type_display, class: 'orange'
              else
                status_tag operation.operation_type_display
              end
            end
            column :admin_user
            column :created_at
          end
        else
          para "暂无操作记录"
        end
      end
  end

  # 表单使用 partial
  form partial: "form"
  
  # 原始表单实现已移至 _form.html.erb
  # 以下代码已注释掉，不再使用
  # form title: proc { |wo| wo.new_record? ? "新建审核工单" : ((wo.approved? || wo.rejected?) ? "查看已处理审核工单 ##{wo.id}" : "编辑审核工单 ##{wo.id}") } do |f|
  #   if f.object.approved? || f.object.rejected?
  #     f.inputs "工单已处理" do
  #       para "此工单已审核通过或拒绝，通常不再编辑。"
  #     end
  #   else
  #     f.semantic_errors
  #
  #     reimbursement = f.object.reimbursement || (params[:reimbursement_id] ? Reimbursement.find_by(id: params[:reimbursement_id]) : nil)
  #
  #     tabs do
  #       tab '基本信息' do
  #         f.inputs '工单详情' do
  #           if reimbursement
  #             render 'admin/reimbursements/reimbursement_display', reimbursement: reimbursement
  #             f.input :reimbursement_id, as: :hidden, input_html: { value: reimbursement.id }
  #             #f.input :reimbursement_invoice_number, label: '报销单号', input_html: { value: reimbursement.invoice_number, readonly: true, disabled: true }
  #           elsif f.object.reimbursement
  #              f.input :reimbursement_invoice_number, label: '报销单号', input_html: { value: f.object.reimbursement.invoice_number, readonly: true, disabled: true }
  #           end
  #           f.input :status, input_html: { readonly: true, disabled: true }, label: '工单状态' if f.object.persisted?
  #         end
  #
  #         # Updated Fee Detail Section
  #         if reimbursement
  #           render 'admin/shared/fee_details_selection', work_order: f.object, reimbursement: reimbursement
  #         else
  #           f.inputs '费用明细' do
  #             para "无法加载费用明细，未关联有效的报销单。"
  #           end
  #         end
  #
  #         f.inputs '处理与反馈' do
  #           f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all, include_blank: '请选择处理意见', input_html: { id: 'audit_work_order_processing_opinion' }
  #
  #           # 移除费用类型和问题类型下拉选择
  #           # 问题类型选择已在费用明细选择部分实现
  #
  #           # 审核意见输入框
  #           f.input :audit_comment, label: "审核意见",
  #                   input_html: { id: 'audit_comment_field' },
  #                   wrapper_html: { id: 'audit_comment_row', style: 'display:none;' }
  #
  #           f.input :remark, label: "备注", wrapper_html: { id: 'remark_row', style: 'display:none;' }
  #         end
  #       end
  #     end
  #     f.actions
  #
  #     # JavaScript for conditional fields
  #     script do
  #       raw """
  #         document.addEventListener('DOMContentLoaded', function() {
  #           const processingOpinionSelect = document.getElementById('audit_work_order_processing_opinion');
  #           const auditCommentRow = document.getElementById('audit_comment_row');
  #           const remarkRow = document.getElementById('remark_row');
  #           const problemTypesContainer = document.getElementById('problem-types-container');
  #
  #           // 切换字段显示
  #           function toggleFields() {
  #             if (!processingOpinionSelect || !auditCommentRow || !remarkRow) {
  #               return;
  #             }
  #             const selectedValue = processingOpinionSelect.value;
  #
  #             auditCommentRow.style.display = 'none';
  #             remarkRow.style.display = 'none';
  #
  #             if (selectedValue === '无法通过') {
  #               if (problemTypesContainer) {
  #                 problemTypesContainer.style.display = 'block';
  #               }
  #               auditCommentRow.style.display = 'list-item';
  #               remarkRow.style.display = 'list-item';
  #             } else if (selectedValue === '可以通过') {
  #               if (problemTypesContainer) {
  #                 problemTypesContainer.style.display = 'none';
  #               }
  #               auditCommentRow.style.display = 'list-item';
  #             } else { // Blank
  #               if (problemTypesContainer) {
  #                 problemTypesContainer.style.display = 'none';
  #               }
  #               auditCommentRow.style.display = 'list-item';
  #             }
  #           }
  #
  #           // 设置事件监听器
  #           if (processingOpinionSelect) {
  #             processingOpinionSelect.addEventListener('change', toggleFields);
  #             toggleFields();
  #           }
  #         });
  #       """
  #     end
  #   end
  # end
  
  # 处理意见与状态关系由模型的 set_status_based_on_processing_opinion 回调自动处理
  
  # 移除控制器方法处理处理意见与状态关系
  # 处理意见与状态的关系由模型的 set_status_based_on_processing_opinion 回调自动处理
end