ActiveAdmin.register CommunicationWorkOrder do
  permit_params :reimbursement_id, :communication_method,
                :initiator_role, :resolution_summary, :creator_id,
                # 共享字段 (Req 6/7)
                :problem_type, :problem_description, :remark, :processing_opinion,
                :needs_communication,
                fee_detail_ids: []
  # 移除 status 从 permit_params 中，状态由系统自动管理

  menu priority: 5, label: "沟通工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'

  controller do
    def scoped_collection
      CommunicationWorkOrder.includes(:reimbursement, :creator) # 移除 audit_work_order 关联
    end

    # 创建时设置报销单ID (移除审核工单ID设置)
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      resource
    end
    
    # 重写创建方法，确保设置creator_id
    def create
      params[:communication_work_order][:creator_id] = current_admin_user.id
      
      # 添加调试日志
      Rails.logger.info "CommunicationWorkOrder create: params[:communication_work_order][:fee_detail_ids] = #{params[:communication_work_order][:fee_detail_ids].inspect}"
      
      # 保存费用明细IDs，确保在重定向后仍然可用
      fee_detail_ids = params[:communication_work_order][:fee_detail_ids]
      
      # 使用ActiveAdmin的permit_params定义的参数
      communication_work_order_params = params.require(:communication_work_order).permit(
        :reimbursement_id, :communication_method, :initiator_role, :resolution_summary,
        :problem_type, :problem_description, :remark, :processing_opinion, :needs_communication
      )
      
      @communication_work_order = CommunicationWorkOrder.new(communication_work_order_params)
      @communication_work_order.creator_id = current_admin_user.id
      @communication_work_order.status = 'pending' # 设置初始状态
      
      # 设置@fee_detail_ids_to_select以通过验证
      if fee_detail_ids.present?
        @communication_work_order.instance_variable_set(:@fee_detail_ids_to_select, fee_detail_ids)
      end
      
      if @communication_work_order.save
        Rails.logger.info "CommunicationWorkOrder create: 保存成功，ID=#{@communication_work_order.id}"
        
        # 手动处理费用明细选择
        if fee_detail_ids.present?
          Rails.logger.info "CommunicationWorkOrder create: 开始处理费用明细选择，IDs=#{fee_detail_ids.inspect}"
          
          fee_details = FeeDetail.where(id: fee_detail_ids, document_number: @communication_work_order.reimbursement.invoice_number)
          Rails.logger.info "找到 #{fee_details.count} 个匹配的费用明细"
          
          fee_details.each do |fee_detail|
            # 显式指定work_order_type为'CommunicationWorkOrder'
            selection = FeeDetailSelection.find_or_create_by(
              fee_detail: fee_detail,
              work_order_id: @communication_work_order.id,
              work_order_type: 'CommunicationWorkOrder'
            )
            selection.update(verification_status: fee_detail.verification_status)
            Rails.logger.info "创建/更新费用明细选择 ##{selection.id} 关联费用明细 ##{fee_detail.id}"
          end
        else
          Rails.logger.info "CommunicationWorkOrder create: 没有费用明细IDs需要处理"
        end
        
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已成功创建"
      else
        Rails.logger.info "CommunicationWorkOrder create: 保存失败，错误: #{@communication_work_order.errors.full_messages.join(', ')}"
        flash.now[:error] = "创建沟通工单失败: #{@communication_work_order.errors.full_messages.join(', ')}"
        render :new
      end
    end
  end

  # 过滤器 (移除 audit_work_order_id 过滤器)
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: CommunicationWorkOrder.state_machines[:status].states.map(&:value)
  filter :communication_method
  filter :initiator_role
  filter :needs_communication, as: :boolean, label: '需要沟通'
  filter :problem_type, as: :select, collection: ProblemTypeOptions.all
  filter :creator
  filter :created_at

  # 范围过滤器
  scope :all, default: true
  scope :pending
  scope :processing
  scope :needs_communication
  scope :approved
  scope :rejected

  # 操作按钮
  action_item :start_processing, only: :show, if: proc { resource.pending? } do
    link_to "开始处理", start_processing_admin_communication_work_order_path(resource), method: :post, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :toggle_needs_communication, only: :show do
    if resource.needs_communication?
      link_to "取消需要沟通标记", toggle_needs_communication_admin_communication_work_order_path(resource), method: :post, data: { confirm: "确定要取消需要沟通标记吗?" }
    else
      link_to "标记为需要沟通", toggle_needs_communication_admin_communication_work_order_path(resource), method: :post, data: { confirm: "确定要标记为需要沟通吗?" }
    end
  end
  action_item :approve, only: :show, if: proc { resource.pending? || resource.processing? || resource.needs_communication? } do
    link_to "沟通后通过", approve_admin_communication_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? || resource.needs_communication? } do
    link_to "沟通后拒绝", reject_admin_communication_work_order_path(resource)
  end
  action_item :add_communication_record, only: :show do
    link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource)
  end

  # 成员操作
  member_action :start_processing, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.start_processing
      redirect_to admin_communication_work_order_path(resource), notice: "工单已开始处理"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :toggle_needs_communication, method: :post do
    @work_order = CommunicationWorkOrder.find(params[:id])
    service = CommunicationWorkOrderService.new(@work_order, current_admin_user)
    
    if service.toggle_needs_communication
      redirect_to admin_communication_work_order_path(@work_order),
        notice: @work_order.needs_communication? ? "已标记为需要沟通" : "已取消需要沟通标记"
    else
      redirect_to admin_communication_work_order_path(@work_order),
        alert: "无法更新沟通标志: #{@work_order.errors.full_messages.join(', ')}"
    end
  end

  member_action :approve, method: :get do
    @communication_work_order = resource
    render :approve # 渲染 app/views/admin/communication_work_orders/approve.html.erb
  end

  member_action :do_approve, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:communication_work_order).permit(:resolution_summary, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.approve(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "工单已沟通通过"
    else
      @communication_work_order = resource
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    @communication_work_order = resource
    render :reject # 渲染 app/views/admin/communication_work_orders/reject.html.erb
  end

  member_action :do_reject, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:communication_work_order).permit(:resolution_summary, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.reject(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "工单已沟通拒绝"
    else
      @communication_work_order = resource
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :reject
    end
  end

  # 沟通记录操作
  member_action :new_communication_record, method: :get do
     @communication_work_order = resource
     @communication_record = resource.communication_records.build
     render :new_communication_record # 渲染 app/views/admin/communication_work_orders/new_communication_record.html.erb
  end

  member_action :create_communication_record, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    record = service.add_communication_record(params.require(:communication_record).permit(:content, :communicator_role, :communicator_name, :communication_method))
    if record.persisted?
      redirect_to admin_communication_work_order_path(resource), notice: "沟通记录已添加"
    else
      @communication_work_order = resource
      @communication_record = record
      flash.now[:alert] = "添加沟通记录失败: #{record.errors.full_messages.join(', ')}"
      render :new_communication_record
    end
  end

   # 费用明细验证操作
   member_action :verify_fee_detail, method: :get do
      @work_order = resource
      @fee_detail = FeeDetail.joins(:fee_detail_selections)
                            .where(fee_detail_selections: {work_order_id: resource.id, work_order_type: 'CommunicationWorkOrder'})
                            .find(params[:fee_detail_id])
      render 'admin/shared/verify_fee_detail'
   end

   member_action :do_verify_fee_detail, method: :post do
     service = CommunicationWorkOrderService.new(resource, current_admin_user)
     if service.update_fee_detail_verification(params[:fee_detail_id], params[:verification_status], params[:comment])
        redirect_to admin_communication_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
     else
        @work_order = resource
        @fee_detail = FeeDetail.joins(:fee_detail_selections)
                              .where(fee_detail_selections: {work_order_id: resource.id, work_order_type: 'CommunicationWorkOrder'})
                              .find(params[:fee_detail_id])
        flash.now[:alert] = "费用明细 ##{params[:fee_detail_id]} 更新失败: #{@fee_detail.errors.full_messages.join(', ')}"
        render 'admin/shared/verify_fee_detail'
     end
   end

  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :status do |wo| status_tag wo.status end
    column :problem_type
    column :problem_description
    column :needs_communication do |wo| status_tag wo.needs_communication? ? "需要沟通" : "无需沟通" end
    column :initiator_role
    column :creator
    column :created_at
    actions
  end

  # 详情页
  show title: proc{|wo| "沟通工单 ##{wo.id}" } do
     tabs do
       tab "基本信息" do
         attributes_table do
           row :id
           row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
           row :type
           row :status do |wo| status_tag wo.status end
           row :communication_method
           row :initiator_role
           row :resolution_summary
           row :needs_communication do |wo| status_tag wo.needs_communication? ? "需要沟通" : "无需沟通" end
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

       tab "沟通记录 (#{resource.communication_records.count})" do
          panel "沟通记录" do
            table_for resource.communication_records.order(recorded_at: :desc) do
              column :id
              column :communicator_role
              column :communicator_name
              column :communication_method
              column :content
              column :recorded_at
            end
          end
          div class: "action_items" do
             span class: "action_item" do
               link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource), class: "button"
             end
          end
       end

       tab "费用明细 (#{FeeDetail.joins(:fee_detail_selections).where(fee_detail_selections: {work_order_id: resource.id, work_order_type: 'CommunicationWorkOrder'}).count})" do
          panel "费用明细信息" do
            table_for FeeDetailSelection.where(work_order_id: resource.id, work_order_type: 'CommunicationWorkOrder').includes(:fee_detail) do |selection|
               column "费用明细ID", :fee_detail_id do |sel| link_to sel.fee_detail_id, admin_fee_detail_path(sel.fee_detail) end
               column "费用类型", :fee_type do |sel| sel.fee_detail.fee_type end
               column "金额", :amount do |sel| number_to_currency(sel.fee_detail.amount, unit: "¥") end
               column "全局状态", :global_status do |sel| status_tag sel.fee_detail.verification_status end
               column "工单内状态", :verification_status do |sel| status_tag sel.verification_status end
               column "验证意见", :verification_comment
               column "操作" do |sel|
                 link_to("更新验证状态", verify_fee_detail_admin_communication_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
               end
            end
          end
       end

       tab "状态变更历史" do
          panel "状态变更历史" do
            table_for WorkOrderStatusChange.where(work_order_id: resource.id, work_order_type: 'CommunicationWorkOrder').order(changed_at: :desc) do
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

  # 表单使用 partial
  form partial: 'form'
  
  # 处理意见与状态关系由模型的 set_status_based_on_processing_opinion 回调自动处理
  
  # 移除控制器方法处理处理意见与状态关系
  # 处理意见与状态的关系由模型的 set_status_based_on_processing_opinion 回调自动处理
end