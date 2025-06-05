ActiveAdmin.register CommunicationWorkOrder do
  permit_params :reimbursement_id, :audit_comment, # creator_id by controller, audit_date by system
                 # Shared fields
                 :processing_opinion,
                 submitted_fee_detail_ids: [], problem_type_ids: []
  # 移除 problem_type_id 和 fee_type_id 从 permit_params 中，改为使用 problem_type_ids 数组

  menu priority: 5, label: "沟通工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'
  config.remove_action_item :new # Assuming new is not created directly, but from Reimbursement

  controller do
    before_action :set_current_admin_user_for_model

    def set_current_admin_user_for_model
      Current.admin_user = current_admin_user
    end

    def scoped_collection
      CommunicationWorkOrder.includes(:reimbursement, :creator, :fee_details) # 预加载更多关联
    end

    # 创建时设置报销单ID
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # 如果是从表单提交的，设置 submitted_fee_detail_ids
      if params[:communication_work_order] && params[:communication_work_order][:submitted_fee_detail_ids]
        # 添加调试日志
        Rails.logger.debug "CommunicationWorkOrder build_new_resource: 设置 submitted_fee_detail_ids 为 #{params[:communication_work_order][:submitted_fee_detail_ids].inspect}"
        resource.submitted_fee_detail_ids = params[:communication_work_order][:submitted_fee_detail_ids]
        # 检查设置后的值
        Rails.logger.debug "CommunicationWorkOrder build_new_resource: 设置后 submitted_fee_detail_ids 为 #{resource.submitted_fee_detail_ids.inspect}"
      else
        Rails.logger.debug "CommunicationWorkOrder build_new_resource: 没有 submitted_fee_detail_ids 参数"
      end
      resource
    end
    
    # Updated create action
    def create
      # Permit submitted_fee_detail_ids along with other attributes
      # Parameters should align with the main permit_params, using _id for problem type
      _communication_work_order_params = params.require(:communication_work_order).permit(
        :reimbursement_id, :audit_comment, # creator_id by controller, audit_date by system
        :processing_opinion,
        submitted_fee_detail_ids: [], problem_type_ids: []
      )
      
      Rails.logger.debug "CommunicationWorkOrdersController#create: 参数: #{_communication_work_order_params.inspect}"

      # 创建工单实例
      @communication_work_order = CommunicationWorkOrder.new(_communication_work_order_params.except(:submitted_fee_detail_ids, :problem_type_ids))
      @communication_work_order.created_by = current_admin_user.id

      if _communication_work_order_params[:submitted_fee_detail_ids].present?
        # Set the special instance variable for the callback in WorkOrder model
        @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, _communication_work_order_params[:submitted_fee_detail_ids])
        # Also set the accessor for form repopulation if validation fails and we re-render new
        @communication_work_order.submitted_fee_detail_ids = _communication_work_order_params[:submitted_fee_detail_ids]
      end
      
      # 设置问题类型IDs
      if _communication_work_order_params[:problem_type_ids].present?
        @communication_work_order.problem_type_ids = _communication_work_order_params[:problem_type_ids]
      end
      
      if @communication_work_order.save
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已成功创建"
      else
        Rails.logger.debug "CommunicationWorkOrder save failed. Errors: #{@communication_work_order.errors.full_messages.inspect}" # DEBUG LINE
        # Re-fetch reimbursement if save fails, needed for the form on render :new
        @reimbursement = Reimbursement.find_by(id: _communication_work_order_params[:reimbursement_id])
        # Ensure @_direct_submitted_fee_ids is set for the callback if save is retried from a re-rendered form (though less likely)
        # and submitted_fee_detail_ids (accessor) is set for form repopulation.
        if _communication_work_order_params[:submitted_fee_detail_ids].present? 
          @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, _communication_work_order_params[:submitted_fee_detail_ids])
          @communication_work_order.submitted_fee_detail_ids = _communication_work_order_params[:submitted_fee_detail_ids]
        end
        # 重新设置问题类型IDs
        if _communication_work_order_params[:problem_type_ids].present?
          @communication_work_order.problem_type_ids = _communication_work_order_params[:problem_type_ids]
        end
        flash.now[:error] = "创建沟通工单失败: #{@communication_work_order.errors.full_messages.join(', ')}"
        render :new
      end
    end

    # Update action might need review if fee details were editable here before
    def update
      @communication_work_order = CommunicationWorkOrder.find(params[:id])
      service = WorkOrderService.new(@communication_work_order, current_admin_user)
      
      update_params = communication_work_order_params_for_update
      if update_params[:submitted_fee_detail_ids].present?
        @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, update_params[:submitted_fee_detail_ids])
        # For form repopulation on error, also set the accessor if it exists
        @communication_work_order.submitted_fee_detail_ids = update_params[:submitted_fee_detail_ids] if @communication_work_order.respond_to?(:submitted_fee_detail_ids=)
      end
      
      # 设置问题类型IDs
      if update_params[:problem_type_ids].present?
        @communication_work_order.problem_type_ids = update_params[:problem_type_ids]
      end

      # Use the centrally defined communication_work_order_params method for strong parameters
      # The service update method should ideally only take attributes for the model itself, not the fee IDs which are handled by callback
      if service.update(update_params.except(:submitted_fee_detail_ids, :problem_type_ids)) 
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: '沟通工单已更新'
      else
        # If update fails, @_direct_submitted_fee_ids might need to be preserved or reset for the form
        # For now, assume submitted_fee_detail_ids accessor helps repopulate via the form builder if re-rendering edit
        render :edit
      end
    end

    private
    
    # Renamed to communication_work_order_params_for_update to be specific for the update action context
    def communication_work_order_params_for_update
      params.require(:communication_work_order).permit(
        :processing_opinion,
        :audit_comment,
        submitted_fee_detail_ids: [],
        problem_type_ids: []
      )
    end
  end

  # 过滤器 - Temporarily disabled to fix the "First argument in form cannot contain nil or be empty" error
  # filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  # filter :status, as: :select, collection: -> { CommunicationWorkOrder.state_machine(:status).states.map(&:value) }
  # filter :creator # 过滤创建人
  # filter :created_at
  
  # Disable filters completely
  config.filters = false

  # 范围过滤器
  scope :all, default: true
  scope :pending
  # scope :processing # REMOVED: 'processing' state and scope were removed from WorkOrder model
  scope :approved
  scope :rejected
  scope :completed

  # 操作按钮
  action_item :approve, only: :show, if: proc { resource.pending? } do
    link_to "审核通过", approve_admin_communication_work_order_path(resource) # Leads to a form
  end

  action_item :reject, only: :show, if: proc { resource.pending? } do
    link_to "审核拒绝", reject_admin_communication_work_order_path(resource) # Leads to a form
  end

  # 自定义操作
  member_action :approve, method: :get do
    redirect_to admin_communication_work_order_path(resource), alert: "工单已审核或已拒绝，无法再次操作。" if resource.approved? || resource.rejected?
    @communication_work_order = resource
    render :approve # 渲染 app/views/admin/communication_work_orders/approve.html.erb
  end

  member_action :do_approve, method: :post do
    # Use the base WorkOrderService
    service = WorkOrderService.new(resource, current_admin_user)
    # Params should align with what WorkOrderService and WorkOrder model expect
    # Ensure :processing_opinion is part of the permitted params for approval logic
    permitted_params = params.require(:communication_work_order).permit(
      :audit_comment, :processing_opinion,
      :vat_verified, # CommunicationWorkOrder specific, if still needed here
      problem_type_ids: []
    ).merge(processing_opinion: '可以通过') # Explicitly set for approval

    if service.approve(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "审核已通过"
    else
      @communication_work_order = resource # 重新赋值用于表单渲染
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    redirect_to admin_communication_work_order_path(resource), alert: "工单已审核或已拒绝，无法再次操作。" if resource.approved? || resource.rejected?
    @communication_work_order = resource
    render :reject # 渲染 app/views/admin/communication_work_orders/reject.html.erb
  end

  member_action :do_reject, method: :post do
    # Use the base WorkOrderService
    service = WorkOrderService.new(resource, current_admin_user)
    # Params should align with what WorkOrderService and WorkOrder model expect
    # Ensure :processing_opinion is part of the permitted params for rejection logic
    permitted_params = params.require(:communication_work_order).permit(
      :audit_comment, :processing_opinion,
      :vat_verified, # CommunicationWorkOrder specific, if still needed here
      problem_type_ids: []
    ).merge(processing_opinion: '无法通过') # Explicitly set for rejection

    if service.reject(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "审核已拒绝"
    else
       @communication_work_order = resource # 重新赋值用于表单渲染
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :reject
    end
  end

  member_action :verify_fee_detail, method: :get do
     @work_order = resource
     # 使用新的关联查找 fee_detail
     @fee_detail = @work_order.fee_details.find_by(id: params[:fee_detail_id])
     unless @fee_detail
       redirect_to admin_communication_work_order_path(@work_order), alert: "未找到关联的费用明细 ##{params[:fee_detail_id]}"
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
      redirect_to admin_communication_work_order_path(resource), notice: "费用明细 ##{fee_detail_id} 状态已更新"
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
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :status do |wo| status_tag wo.status end
    column "问题类型", :problem_types do |wo| 
      if wo.problem_types.any?
        wo.problem_types.map(&:display_name).join(", ")
      else
        # 兼容旧数据
        wo.problem_type&.display_name
      end
    end
    column :creator
    column :created_at
    column :updated_at
    column "操作" do |work_order|
      links = ActiveSupport::SafeBuffer.new
      links << link_to("查看", admin_communication_work_order_path(work_order), class: "member_link view_link")
      if work_order.editable?
        links << link_to("编辑", edit_admin_communication_work_order_path(work_order), class: "member_link edit_link")
        links << link_to("删除", admin_communication_work_order_path(work_order), method: :delete, data: { confirm: "确定要删除吗?" }, class: "member_link delete_link")
      end
      links
    end
  end

  # 详情页
  show title: proc{|wo| "沟通工单 ##{wo.id}" } do
    
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
      row :audit_comment
      row :audit_date
      row :creator
      row :created_at
      row :updated_at
    end
  
    # 工单相关信息专用显示区
    panel "工单相关信息" do
      columns do
        column do
          panel "费用类型" do
            # 从费用明细中提取费用类型字符串
            fee_type_strings = resource.fee_details.map(&:fee_type).compact.uniq
            
            if fee_type_strings.any?
              # 显示费用类型字符串
              table_for fee_type_strings do
                column "费用类型名称" do |fee_type_string|
                  fee_type_string
                end
                column "系统匹配" do |fee_type_string|
                  # 尝试查找匹配的FeeType对象（仅匹配title）
                  fee_type = FeeType.find_by(title: fee_type_string)
                  if fee_type
                    status_tag "已匹配", class: "green"
                  else
                    status_tag "未匹配", class: "red"
                  end
                end
              end
            else
              para "无关联费用类型"
            end
          end
        end
        
        column do
          panel "问题类型" do
            if resource.problem_types.any?
              table_for resource.problem_types do
                column "编码", :code
                column "名称", :display_name
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
        end
      end
      
      panel "审核意见" do
        attributes_table_for resource do
          row :processing_opinion do |wo|
            if wo.processing_opinion.present?
              status_class = case wo.processing_opinion
                             when '可以通过'
                               'green'
                             when '无法通过'
                               'red'
                             else
                               'orange'
                             end
              status_tag wo.processing_opinion, class: status_class
            else
              span "未填写", class: "empty"
            end
          end
          row :audit_comment
        end
      end
    end

    # panel for Fee Details (原"费用明细"Tab内容)
    panel "关联的费用明细" do
      table_for communication_work_order.fee_details do
        column "ID" do |fee_detail|
          link_to fee_detail.id, admin_fee_detail_path(fee_detail)
        end
        column "费用类型", :fee_type
        column "金额" do |fee_detail|
          number_to_currency(fee_detail.amount, unit: "¥")
        end
        column "费用日期", :fee_date
        column "备注", :notes
        column "创建时间", :created_at
        column "更新时间", :updated_at
      end
    end
    
    # 操作记录面板
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
end