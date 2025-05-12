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
      _params = params.require(:communication_work_order).permit(
        :reimbursement_id, :audit_comment,
        :problem_type_id, :problem_description_id, :remark, :processing_opinion,
        submitted_fee_detail_ids: [] # Align with top-level permit_params
      )

      @communication_work_order = CommunicationWorkOrder.new(_params.except(:submitted_fee_detail_ids))
      @communication_work_order.creator_id = current_admin_user.id
      # @communication_work_order.status = 'pending' # Initial status set by state_machine default

      if _params[:submitted_fee_detail_ids].present?
        @communication_work_order.submitted_fee_detail_ids = _params[:submitted_fee_detail_ids]
      end
      
      if @communication_work_order.save
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已成功创建" # Changed label
      else
        @reimbursement = Reimbursement.find_by(id: _params[:reimbursement_id])
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
  filter :resolution, label: "处理结果", as: :select, collection: -> { CommunicationWorkOrder.state_machine(:resolution).states.map(&:value) }
  filter :audit_comment
  filter :problem_type_id, as: :select, collection: -> { ProblemType.all.map { |pt| [pt.name, pt.id] } }
  filter :creator
  filter :created_at

  scope :all, default: true
  scope :pending
  scope :processing
  scope :approved
  scope :rejected

  action_item :start_processing, only: :show, if: proc { resource.pending? } do
    link_to "开始处理", start_processing_admin_communication_work_order_path(resource), method: :post, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :approve, only: :show, if: proc { resource.pending? || resource.processing? } do
    link_to "审核通过", approve_admin_communication_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? } do
    link_to "审核拒绝", reject_admin_communication_work_order_path(resource)
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

  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :status do |wo| status_tag wo.status end
    column "处理结果", :resolution do |wo| status_tag wo.resolution if wo.resolution.present? end
    column :audit_comment
    column :problem_type_id do |wo| wo.problem_type&.name end
    column :processing_opinion
    column :creator
    column :created_at
    column :updated_at
    actions
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
        row "处理结果", :resolution do |wo| status_tag wo.resolution if wo.resolution.present? end
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
        column "验证状态" do |fee_detail|
          status_tag fee_detail.verification_status, class: case fee_detail.verification_status
                                                            when FeeDetail::VERIFICATION_STATUS_VERIFIED
                                                              'ok' # green
                                                            when FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
                                                              'error' # red
                                                            else
                                                              'warning' # orange
                                                            end
        end
        column "备注", :notes
      end
    end
  end

  form do |f|
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

        # Updated Fee Detail Section (Conditional display)
        if reimbursement
          if f.object.persisted? # EDIT MODE: Show read-only list
            panel "已关联的费用明细" do
              if f.object.fee_details.any?
                table_for f.object.fee_details.order(created_at: :desc) do
                  column(:id) { |fd| link_to fd.id, admin_fee_detail_path(fd) }
                  column :fee_type
                  column "金额", :amount do |fd| number_to_currency(fd.amount, unit: "¥") end
                  column "备注", :notes # Using notes
                  column "验证状态", :verification_status do |fd| status_tag fd.verification_status end
                end
              else
                para "此工单当前未关联任何费用明细。"
              end
            end
          else # NEW MODE: Show checkboxes for selection
            panel "选择关联的费用明细" do
              available_fee_details = FeeDetail.where(document_number: reimbursement.invoice_number)
              if available_fee_details.any?
                selected_ids = [] # Always empty for new
                # Ensure this uses fd.notes or the correct field name for FeeDetail description
                f.input :submitted_fee_detail_ids, as: :check_boxes, 
                        collection: available_fee_details.map { |fd| ["ID: #{fd.id} - #{fd.notes} (¥#{fd.amount})", fd.id] },
                        selected: selected_ids,
                        label: false
              else
                para "此报销单没有可供选择的费用明细。"
              end
            end
          end
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