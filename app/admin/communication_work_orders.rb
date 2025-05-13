ActiveAdmin.register CommunicationWorkOrder do
  permit_params :reimbursement_id, :audit_comment, # creator_id by controller, audit_date by system
                # Shared fields (initiator_role & communication_method removed)
                :problem_type_id, :problem_description_id, :remark, :processing_opinion,
                submitted_fee_detail_ids: [] # Renamed from fee_detail_ids

  menu priority: 5, label: "沟通工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'
  config.remove_action_item :new # Assuming new is not created directly, but from Reimbursement

  controller do
    def scoped_collection
      CommunicationWorkOrder.includes(:reimbursement, :creator, :problem_type, :problem_description, :fee_details) # Added problem_type, problem_description, fee_details
    end

    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # Use submitted_fee_detail_ids
      if params[:communication_work_order] && params[:communication_work_order][:submitted_fee_detail_ids]
        resource.submitted_fee_detail_ids = params[:communication_work_order][:submitted_fee_detail_ids].reject(&:blank?)
      end
      resource
    end
    
    def create
      # Permit all attributes for communication_work_order, including potentially submitted_fee_detail_ids
      # This aligns with the main `permit_params` definition for the resource.
      _params = params.require(:communication_work_order).permit(
        :reimbursement_id, :audit_comment,
        :problem_type_id, :problem_description_id, :remark, :processing_opinion,
        submitted_fee_detail_ids: [] 
      )

      @communication_work_order = CommunicationWorkOrder.new(_params.except(:submitted_fee_detail_ids))
      @communication_work_order.creator_id = current_admin_user.id

      # Attempt to load submitted_fee_detail_ids
      # First from the correctly nested params (as permitted above)
      current_submitted_ids = _params[:submitted_fee_detail_ids]

      # If empty, check the incorrectly nested params (from audit_work_order key)
      # Ensure params.dig(:audit_work_order, :submitted_fee_detail_ids) is not nil before calling present?
      if current_submitted_ids.blank? && params.dig(:audit_work_order, :submitted_fee_detail_ids).present?
        misplaced_ids = params.dig(:audit_work_order, :submitted_fee_detail_ids)
        Rails.logger.warn "CommunicationWorkOrder create: submitted_fee_detail_ids found under 'audit_work_order' key. " \
                          "The shared partial '_fee_details_selection.html.erb' likely needs correction to use a dynamic param key " \
                          "instead of hardcoding 'audit_work_order'."
        current_submitted_ids = misplaced_ids
      end
      
      # Assign to the model instance variable that the callback uses
      if current_submitted_ids.present?
        @communication_work_order.submitted_fee_detail_ids = current_submitted_ids.reject(&:blank?)
      end
      
      if @communication_work_order.save
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已成功创建" # Changed label
      else
        @reimbursement = Reimbursement.find_by(id: _params[:reimbursement_id])
        # submitted_fee_detail_ids are already set on @communication_work_order instance for form repopulation
        flash.now[:error] = "创建沟通工单失败: #{@communication_work_order.errors.full_messages.join(', ')}" # Changed label
        render :new
      end
    end

    def update
      @communication_work_order = CommunicationWorkOrder.find(params[:id])
      service = CommunicationWorkOrderService.new(@communication_work_order, current_admin_user)
      
      # Use the renamed strong params method
      if service.update(communication_work_order_params_for_update)
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: '沟通工单已更新'
      else
        render :edit
      end
    end

    private
    
    # Renamed for clarity and consistency
    def communication_work_order_params_for_update
      params.require(:communication_work_order).permit(
        :processing_opinion,
        :problem_type_id,
        :problem_description_id,
        :audit_comment,
        :remark,
        submitted_fee_detail_ids: [] # If editable
      )
    end
  end

  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: -> { CommunicationWorkOrder.state_machine(:status).states.map(&:value) }
  filter :audit_comment
  filter :problem_type_id, as: :select, collection: -> { ProblemType.all.map { |pt| [pt.name, pt.id] } }
  filter :creator
  filter :created_at

  scope :all, default: true
  scope :pending
  scope :processing
  scope :approved
  scope :rejected

  action_item :delete_reimbursement, only: :show, priority: 3, if: proc { !resource.completed? } do
    link_to "删除报销单", admin_reimbursement_path(resource.reimbursement),
            method: :delete,
            data: { confirm: "确定要删除此报销单吗？此操作将删除所有相关联的沟通工单。" }
  end

  action_item :start_processing, only: :show, if: proc { resource.pending? && !resource.completed? } do
    link_to "开始处理", start_processing_admin_communication_work_order_path(resource), method: :post, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :approve, only: :show, if: proc { (resource.pending? || resource.processing?) && !resource.completed? } do
    link_to "审核通过", approve_admin_communication_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? && !resource.completed? } do
    link_to "审核拒绝", reject_admin_communication_work_order_path(resource)
  end
  action_item :mark_as_complete, only: :show, if: proc { (resource.status == 'approved' || resource.status == 'rejected') && !resource.completed? } do
    link_to "审核完成", mark_as_complete_admin_communication_work_order_path(resource), method: :post, data: { confirm: "确定要将此工单标记为完成吗？此操作将锁定工单。" }
  end

  member_action :start_processing, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.start_processing
      redirect_to admin_communication_work_order_path(resource), notice: "工单已开始处理"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :approve, method: :get do
    redirect_to admin_communication_work_order_path(resource), alert: "工单已完成，无法操作。" if resource.completed?
    @communication_work_order = resource
    render :approve
  end

  member_action :do_approve, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    # Align with AuditWorkOrder: primarily audit_comment, maybe processing_opinion
    permitted_params = params.require(:communication_work_order).permit(:audit_comment, :processing_opinion)
    if service.approve(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "沟通工单已审核通过" # Changed label
    else
      @communication_work_order = resource
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    redirect_to admin_communication_work_order_path(resource), alert: "工单已完成，无法操作。" if resource.completed?
    @communication_work_order = resource
    render :reject
  end

  member_action :do_reject, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    # Align with AuditWorkOrder: audit_comment, problem_type_id, problem_description_id, remark, processing_opinion
    permitted_params = params.require(:communication_work_order).permit(
      :audit_comment, 
      :problem_type_id, 
      :problem_description_id, 
      :remark, 
      :processing_opinion
    )
    if service.reject(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "沟通工单已审核拒绝" # Changed label
    else
      @communication_work_order = resource
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :reject
    end
  end

  member_action :verify_fee_detail, method: :get do
    @work_order = resource
    # Use direct association from WorkOrder base model
    @fee_detail = @work_order.fee_details.find_by(id: params[:fee_detail_id])
    unless @fee_detail
      redirect_to admin_communication_work_order_path(@work_order), alert: "未找到关联的费用明细 ##{params[:fee_detail_id]}"
      return
    end
    render 'admin/shared/verify_fee_detail'
  end

  member_action :do_verify_fee_detail, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    # Find fee_detail for re-rendering form on failure
    @fee_detail = resource.fee_details.find_by(id: params[:fee_detail_id])
    unless @fee_detail # Ensure @fee_detail is set before potential error rendering
      redirect_to admin_communication_work_order_path(resource), alert: "尝试验证的费用明细 ##{params[:fee_detail_id]} 未找到或未关联。"
      return
    end

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

  member_action :mark_as_complete, method: :post do
    if resource.completed?
      redirect_to admin_communication_work_order_path(resource), alert: "此工单已标记为完成。"
    elsif resource.status == 'approved' || resource.status == 'rejected'
      if resource.update(completed: true)
        redirect_to admin_communication_work_order_path(resource), notice: "工单已成功标记为完成。"
      else
        redirect_to admin_communication_work_order_path(resource), alert: "标记完成失败: #{resource.errors.full_messages.join(', ')}"
      end
    else
      redirect_to admin_communication_work_order_path(resource), alert: "只有状态为 Approved 或 Rejected 的工单才能标记为完成。"
    end
  end

  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :status do |wo| status_tag wo.status end
    column :audit_comment
    column :problem_type_id do |wo| wo.problem_type&.name end
    column :processing_opinion
    column :creator
    column :created_at
    column :updated_at
    actions do |work_order|
      item "查看", admin_communication_work_order_path(work_order)
      unless work_order.completed?
        item "编辑", edit_admin_communication_work_order_path(work_order), class: "member_link edit_link"
        item "删除", admin_communication_work_order_path(work_order), method: :delete, data: { confirm: "确定要删除吗?" }, class: "member_link delete_link"
      end
    end
  end

  show do
    panel "基本信息" do
      if resource.reimbursement.present?
        render 'admin/reimbursements/reimbursement_display', reimbursement: resource.reimbursement
      end

      attributes_table do
        row :id
        row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) if wo.reimbursement end
        row :status do |wo| status_tag wo.status end
        row :completed do |wo|
          status_tag wo.completed? ? '是' : '否', class: (wo.completed? ? :ok : :warn)
        end
        row :audit_comment
        row :processing_opinion
        row :problem_type_id do |wo| wo.problem_type&.name end
        row :problem_description_id do |wo| wo.problem_description&.description end
        row :remark
        row :creator
        row :created_at
        row :updated_at
      end
    end

    panel "关联的费用明细" do
      table_for resource.fee_details do
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

  form do |f|
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
            # Order: 0. 报销单号
            if reimbursement
              f.input :reimbursement_id, as: :hidden, input_html: { value: reimbursement.id }
              f.input :reimbursement_invoice_number, label: '报销单号', input_html: { value: reimbursement.invoice_number, readonly: true, disabled: true }
            elsif f.object.reimbursement # for edit page if already associated
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
            # Order: 2. 处理意见
            f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all, include_blank: '请选择处理意见', input_html: { id: 'communication_work_order_processing_opinion' }
            
            # Order: 3. 问题类型 (Conditionally Visible)
            f.input :problem_type_id, as: :select, collection: ProblemType.all.map { |pt| [pt.name, pt.id] }, include_blank: '请选择问题类型', wrapper_html: { id: 'communication_problem_type_row', style: 'display:none;' }
            
            # Order: 4. 问题说明 (Conditionally Visible)
            f.input :problem_description_id, as: :select, collection: ProblemDescription.all.map { |pd| [pd.description, pd.id] }, include_blank: '请选择问题描述', wrapper_html: { id: 'communication_problem_description_row', style: 'display:none;' }
            f.input :audit_comment, label: "审核意见", wrapper_html: { id: 'communication_audit_comment_row', style: 'display:none;' }
            # Order: 5. 备注
            f.input :remark, label: "备注", wrapper_html: { id: 'communication_remark_row', style: 'display:none;' }
          end
        end
      end
      f.actions

      # JavaScript for conditional fields (UPDATED LOGIC)
      script do
        raw """
          document.addEventListener('DOMContentLoaded', function() {
            const processingOpinionSelect = document.getElementById('communication_work_order_processing_opinion');
            const problemTypeRow = document.getElementById('communication_problem_type_row');
            const problemDescriptionRow = document.getElementById('communication_problem_description_row');
            const auditCommentRow = document.getElementById('communication_audit_comment_row');
            const remarkRow = document.getElementById('communication_remark_row');

            function toggleFields() {
              if (!processingOpinionSelect || !problemTypeRow || !problemDescriptionRow || !auditCommentRow || !remarkRow) {
                console.warn('One or more conditional fields not found for CommunicationWorkOrder form.');
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
                remarkRow.style.display = 'list-item';
              } else {
                auditCommentRow.style.display = 'list-item';
                remarkRow.style.display = 'list-item';
              }
            }

            if (processingOpinionSelect) {
              processingOpinionSelect.addEventListener('change', toggleFields);
              toggleFields();
            } else {
              console.warn('Processing opinion select not found for CommunicationWorkOrder form.');
            }
          });
        """
      end
    end
  end
end