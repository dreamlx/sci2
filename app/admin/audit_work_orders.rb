ActiveAdmin.register AuditWorkOrder do
  permit_params :reimbursement_id, :audit_result, :audit_comment, :audit_date,
                :vat_verified, :creator_id,
                # 共享字段 (Req 6/7)
                :problem_type, :problem_description, :remark, :processing_opinion,
                fee_detail_ids: []
  # 移除 status 从 permit_params 中，状态由系统自动管理

  menu priority: 4, label: "审核工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'

  controller do
    def scoped_collection
      AuditWorkOrder.includes(:reimbursement, :creator) # 预加载关联数据
    end

    # 创建时设置报销单ID
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # 如果是从表单提交的，设置fee_detail_ids
      if params[:audit_work_order] && params[:audit_work_order][:fee_detail_ids]
        # 添加调试日志
        Rails.logger.debug "AuditWorkOrder build_new_resource: 设置fee_detail_ids为 #{params[:audit_work_order][:fee_detail_ids].inspect}"
        resource.fee_detail_ids = params[:audit_work_order][:fee_detail_ids]
        # 检查设置后的值
        Rails.logger.debug "AuditWorkOrder build_new_resource: 设置后fee_detail_ids为 #{resource.fee_detail_ids.inspect}"
        Rails.logger.debug "AuditWorkOrder build_new_resource: 设置后@fee_detail_ids_to_select为 #{resource.instance_variable_get(:@fee_detail_ids_to_select).inspect}"
      else
        Rails.logger.debug "AuditWorkOrder build_new_resource: 没有fee_detail_ids参数"
      end
      resource
    end
    
    # 重写创建方法，确保设置creator_id
    def create
      params[:audit_work_order][:creator_id] = current_admin_user.id
      # 添加调试日志
      Rails.logger.info "AuditWorkOrder create: params[:audit_work_order][:fee_detail_ids] = #{params[:audit_work_order][:fee_detail_ids].inspect}"
      
      # 保存费用明细IDs，确保在重定向后仍然可用
      fee_detail_ids = params[:audit_work_order][:fee_detail_ids]
      
      # 直接创建AuditWorkOrder并手动处理费用明细选择
      # 使用ActiveAdmin的permit_params定义的参数
      audit_work_order_params = params.require(:audit_work_order).permit(
        :reimbursement_id, :audit_result, :audit_comment, :audit_date,
        :vat_verified, :problem_type, :problem_description, :remark, :processing_opinion
      )
      
      @audit_work_order = AuditWorkOrder.new(audit_work_order_params)
      @audit_work_order.creator_id = current_admin_user.id
      @audit_work_order.status = 'pending' # 设置初始状态
      
      # 设置@fee_detail_ids_to_select以通过验证
      if fee_detail_ids.present?
        @audit_work_order.instance_variable_set(:@fee_detail_ids_to_select, fee_detail_ids)
      end
      
      Rails.logger.info "AuditWorkOrder create: 创建新的AuditWorkOrder实例"
      
      if @audit_work_order.save
        Rails.logger.info "AuditWorkOrder create: 保存成功，ID=#{@audit_work_order.id}"
        
        # 手动处理费用明细选择
        if fee_detail_ids.present?
          Rails.logger.info "AuditWorkOrder create: 开始处理费用明细选择，IDs=#{fee_detail_ids.inspect}"
          
          fee_details = FeeDetail.where(id: fee_detail_ids, document_number: @audit_work_order.reimbursement.invoice_number)
          Rails.logger.info "找到 #{fee_details.count} 个匹配的费用明细"
          
          fee_details.each do |fee_detail|
            # 显式指定work_order_type为'AuditWorkOrder'
            selection = FeeDetailSelection.find_or_create_by(
              fee_detail: fee_detail,
              work_order_id: @audit_work_order.id,
              work_order_type: 'AuditWorkOrder'
            )
            # No longer need to update verification_status as it's been removed
            Rails.logger.info "创建/更新费用明细选择 ##{selection.id} 关联费用明细 ##{fee_detail.id}"
          end
        else
          Rails.logger.info "AuditWorkOrder create: 没有费用明细IDs需要处理"
        end
        
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: "审核工单已成功创建"
      else
        Rails.logger.info "AuditWorkOrder create: 保存失败，错误: #{@audit_work_order.errors.full_messages.join(', ')}"
        flash.now[:error] = "创建审核工单失败: #{@audit_work_order.errors.full_messages.join(', ')}"
        render :new
      end
    end

    # 重写更新方法，确保正确处理处理意见
    def update
      Rails.logger.info "AuditWorkOrder update: params[:audit_work_order] = #{params[:audit_work_order].inspect}"
      
      # 获取当前工单
      @audit_work_order = AuditWorkOrder.find(params[:id])
      
      # 使用ActiveAdmin的permit_params定义的参数
      audit_work_order_params = params.require(:audit_work_order).permit(
        :reimbursement_id, :audit_result, :audit_comment, :audit_date,
        :vat_verified, :problem_type, :problem_description, :remark, :processing_opinion
      )
      
      Rails.logger.info "AuditWorkOrder update: 更新参数 = #{audit_work_order_params.inspect}"
      
      # 记录处理意见变更
      old_processing_opinion = @audit_work_order.processing_opinion
      new_processing_opinion = audit_work_order_params[:processing_opinion]
      
      if @audit_work_order.update(audit_work_order_params)
        Rails.logger.info "AuditWorkOrder update: 更新成功，ID=#{@audit_work_order.id}"
        Rails.logger.info "AuditWorkOrder update: 处理意见从 '#{old_processing_opinion}' 变更为 '#{new_processing_opinion}'"
        
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: "审核工单已成功更新"
      else
        Rails.logger.info "AuditWorkOrder update: 更新失败，错误: #{@audit_work_order.errors.full_messages.join(', ')}"
        flash.now[:error] = "更新审核工单失败: #{@audit_work_order.errors.full_messages.join(', ')}"
        render :edit
      end
    end
  end

  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: AuditWorkOrder.state_machines[:status].states.map(&:value)
  filter :audit_result, as: :select, collection: ["approved", "rejected"]
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
  action_item :start_processing, only: :show, if: proc { resource.pending? } do
    link_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :post, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :approve, only: :show, if: proc { resource.pending? || resource.processing? } do
    link_to "审核通过", approve_admin_audit_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? } do
    link_to "审核拒绝", reject_admin_audit_work_order_path(resource)
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
    @audit_work_order = resource
    render :approve # 渲染 app/views/admin/audit_work_orders/approve.html.erb
  end

  member_action :do_approve, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:audit_work_order).permit(:audit_comment, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.approve(permitted_params)
      redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
    else
      @audit_work_order = resource # 重新赋值用于表单渲染
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    @audit_work_order = resource
    render :reject # 渲染 app/views/admin/audit_work_orders/reject.html.erb
  end

  member_action :do_reject, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:audit_work_order).permit(:audit_comment, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.reject(permitted_params)
      redirect_to admin_audit_work_order_path(resource), notice: "审核已拒绝"
    else
       @audit_work_order = resource # 重新赋值用于表单渲染
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :reject
    end
  end

  # 费用明细验证操作
  member_action :verify_fee_detail, method: :get do
     @work_order = resource # 用于共享视图上下文
     @fee_detail = FeeDetail.joins(:fee_detail_selections)
                           .where(fee_detail_selections: {work_order_id: resource.id, work_order_type: 'AuditWorkOrder'})
                           .find(params[:fee_detail_id])
     render 'admin/shared/verify_fee_detail' # 渲染 app/views/admin/shared/verify_fee_detail.html.erb
  end

  member_action :do_verify_fee_detail, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    # 直接使用参数，不需要嵌套在audit_work_order下
    if service.update_fee_detail_verification(params[:fee_detail_id], params[:verification_status], params[:comment])
       redirect_to admin_audit_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
    else
       @work_order = resource
       @fee_detail = FeeDetail.joins(:fee_detail_selections)
                             .where(fee_detail_selections: {work_order_id: resource.id, work_order_type: 'AuditWorkOrder'})
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
    column :audit_result do |wo| status_tag wo.audit_result if wo.audit_result.present? end
    column :problem_type
    column :creator
    column :created_at
    actions
  end

  # 详情页
  show title: proc{|wo| "审核工单 ##{wo.id}" } do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
          row :type
          row :status do |wo| status_tag wo.status end
          row :audit_result do |wo| status_tag wo.audit_result if wo.audit_result.present? end
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

      tab "费用明细 (#{FeeDetail.joins(:fee_detail_selections).where(fee_detail_selections: {work_order_id: resource.id, work_order_type: 'AuditWorkOrder'}).count})" do
        panel "费用明细信息" do
          table_for FeeDetailSelection.where(work_order_id: resource.id, work_order_type: 'AuditWorkOrder').includes(:fee_detail) do |selection|
            column "费用明细ID", :fee_detail_id do |sel| link_to sel.fee_detail_id, admin_fee_detail_path(sel.fee_detail) end
            column "费用类型", :fee_type do |sel| sel.fee_detail.fee_type end
            column "金额", :amount do |sel| number_to_currency(sel.fee_detail.amount, unit: "¥") end
            column "状态", :status do |sel| status_tag sel.fee_detail.verification_status end
            column "验证意见", :verification_comment
            column "操作" do |sel|
              link_to("更新验证状态", verify_fee_detail_admin_audit_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
            end
          end
        end
      end

      tab "状态变更历史" do
         panel "状态变更历史" do
           table_for WorkOrderStatusChange.where(work_order_id: resource.id, work_order_type: 'AuditWorkOrder').order(changed_at: :desc) do
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