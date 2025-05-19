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
      @communication_work_order.created_by = current_admin_user.id

      current_submitted_ids = _params[:submitted_fee_detail_ids]
      if current_submitted_ids.blank? && params.dig(:audit_work_order, :submitted_fee_detail_ids).present?
        misplaced_ids = params.dig(:audit_work_order, :submitted_fee_detail_ids)
        Rails.logger.warn "CommunicationWorkOrder create: submitted_fee_detail_ids found under 'audit_work_order' key. " \
                          "The shared partial '_fee_details_selection.html.erb' likely needs correction to use a dynamic param key " \
                          "instead of hardcoding 'audit_work_order'."
        current_submitted_ids = misplaced_ids
      end
      
      if current_submitted_ids.present?
        # Set the special instance variable for the callback in WorkOrder model
        @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, current_submitted_ids.reject(&:blank?))
        # Also set the accessor for form repopulation if validation fails and we re-render new
        @communication_work_order.submitted_fee_detail_ids = current_submitted_ids.reject(&:blank?)
      end
      
      if @communication_work_order.save
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已成功创建" # Changed label
      else
        @reimbursement = Reimbursement.find_by(id: _params[:reimbursement_id])
        # Ensure @_direct_submitted_fee_ids and submitted_fee_detail_ids (accessor) are set for form repopulation.
        if current_submitted_ids.present? 
          @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, current_submitted_ids.reject(&:blank?))
          @communication_work_order.submitted_fee_detail_ids = current_submitted_ids.reject(&:blank?)
        end
        flash.now[:error] = "创建沟通工单失败: #{@communication_work_order.errors.full_messages.join(', ')}" # Changed label
        render :new
      end
    end

    def update
      @communication_work_order = CommunicationWorkOrder.find(params[:id])
      # Ensure to use WorkOrderService if CommunicationWorkOrderService is fully deprecated
      service = WorkOrderService.new(@communication_work_order, current_admin_user) 
      
      update_params = communication_work_order_params_for_update
      if update_params[:submitted_fee_detail_ids].present?
        @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, update_params[:submitted_fee_detail_ids])
        # For form repopulation on error, also set the accessor if it exists
        @communication_work_order.submitted_fee_detail_ids = update_params[:submitted_fee_detail_ids] if @communication_work_order.respond_to?(:submitted_fee_detail_ids=)
      end
      
      if service.update(update_params.except(:submitted_fee_detail_ids)) # Pass params without submitted_fee_detail_ids to service
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
  scope :approved
  scope :rejected

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
    # Use the base WorkOrderService for fee detail verification as CommunicationWorkOrderService might be deprecated
    service = WorkOrderService.new(resource, current_admin_user)
    fee_detail_id = params[:fee_detail_id]
    verification_status = params[:verification_status]
    comment = params[:comment]

    # Find fee_detail for re-rendering form on failure
    @fee_detail = resource.fee_details.find_by(id: fee_detail_id)
    unless @fee_detail # Ensure @fee_detail is set before potential error rendering
      redirect_to admin_communication_work_order_path(resource), alert: "尝试验证的费用明细 ##{fee_detail_id} 未找到或未关联。"
      return
    end

    if service.update_fee_detail_verification(fee_detail_id, verification_status, comment)
       redirect_to admin_communication_work_order_path(resource), notice: "费用明细 ##{fee_detail_id} 状态已更新"
    else
       @work_order = resource # Ensure @work_order is set for the shared form
       # @fee_detail is already set above
       flash.now[:alert] = "费用明细 ##{fee_detail_id} 更新失败: #{ @work_order.errors.full_messages.join(', ') + @fee_detail.errors.full_messages.join(', ') }"
       render 'admin/shared/verify_fee_detail'
    end
  end

  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :status do |wo| status_tag wo.status end
    column :audit_comment
    column "问题类型", :problem_type do |wo| wo.problem_type&.name end
    column :processing_opinion
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

  show do
    panel "基本信息" do
      if resource.reimbursement.present?
        render 'admin/reimbursements/reimbursement_display', reimbursement: resource.reimbursement
      end

      attributes_table do
        row :id
        row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) if wo.reimbursement end
        row :status do |wo| status_tag wo.status end
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
    if f.object.approved? || f.object.rejected?
      panel "工单已处理" do
        para "此工单已审核通过或拒绝，通常不再编辑。"
      end
    else
      f.semantic_errors

      reimbursement = f.object.reimbursement || (params[:reimbursement_id] ? Reimbursement.find_by(id: params[:reimbursement_id]) : nil)

      tabs do
        tab '基本信息' do
          f.inputs '工单详情' do
            # Order: 0. 报销单号
            if reimbursement
              render 'admin/reimbursements/reimbursement_display', reimbursement: reimbursement
              f.input :reimbursement_id, as: :hidden, input_html: { value: reimbursement.id }
              #f.input :reimbursement_invoice_number, label: '报销单号', input_html: { value: reimbursement.invoice_number, readonly: true, disabled: true }
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