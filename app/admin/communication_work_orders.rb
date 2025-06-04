ActiveAdmin.register CommunicationWorkOrder do
  permit_params :reimbursement_id, :audit_comment, # creator_id by controller, audit_date by system
                # Shared fields (initiator_role & communication_method removed)
                :fee_type_id, :remark, :processing_opinion,
                submitted_fee_detail_ids: [], problem_type_ids: []
  # 移除 problem_type_id 从 permit_params 中，改为使用 problem_type_ids 数组

  menu priority: 5, label: "沟通工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'
  config.remove_action_item :new # Assuming new is not created directly, but from Reimbursement

  controller do
    def scoped_collection
      CommunicationWorkOrder.includes(:reimbursement, :creator, :problem_type, :fee_details) # Added problem_type, fee_details
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
      # 添加调试日志
      Rails.logger.debug "CommunicationWorkOrdersController#create: 开始创建沟通工单"
      
      # 获取参数
      create_params = params.require(:communication_work_order).permit(
        :reimbursement_id, :audit_comment, # creator_id by controller, audit_date by system
        :fee_type_id, :remark, :processing_opinion,
        submitted_fee_detail_ids: [], problem_type_ids: []
      )
      
      Rails.logger.debug "CommunicationWorkOrdersController#create: 参数: #{create_params.inspect}"

      # 创建工单实例
      @communication_work_order = CommunicationWorkOrder.new(create_params.except(:submitted_fee_detail_ids, :problem_type_ids))
      @communication_work_order.created_by = current_admin_user.id
      
      Rails.logger.debug "CommunicationWorkOrdersController#create: 创建工单实例: #{@communication_work_order.inspect}"

      # 设置服务
      service = CommunicationWorkOrderService.new(@communication_work_order, current_admin_user)
      Rails.logger.debug "CommunicationWorkOrdersController#create: 创建服务实例"

      # 处理费用明细IDs
      if create_params[:submitted_fee_detail_ids].present?
        Rails.logger.debug "CommunicationWorkOrdersController#create: 设置费用明细IDs: #{create_params[:submitted_fee_detail_ids].inspect}"
        @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, create_params[:submitted_fee_detail_ids])
        @communication_work_order.submitted_fee_detail_ids = create_params[:submitted_fee_detail_ids]
      else
        Rails.logger.debug "CommunicationWorkOrdersController#create: 没有提供费用明细IDs"
      end
      
      # 设置问题类型IDs
      if create_params[:problem_type_ids].present?
        Rails.logger.debug "CommunicationWorkOrdersController#create: 设置问题类型IDs: #{create_params[:problem_type_ids].inspect}"
        @communication_work_order.problem_type_ids = create_params[:problem_type_ids]
      else
        Rails.logger.debug "CommunicationWorkOrdersController#create: 没有提供问题类型IDs"
      end
      
      # 使用服务保存工单
      Rails.logger.debug "CommunicationWorkOrdersController#create: 调用 service.update 方法"
      result = service.update(create_params.except(:submitted_fee_detail_ids, :problem_type_ids))
      Rails.logger.debug "CommunicationWorkOrdersController#create: service.update 返回结果: #{result}"
      
      if result
        Rails.logger.debug "CommunicationWorkOrdersController#create: 创建成功，重定向到详情页"
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已成功创建"
      else
        Rails.logger.error "CommunicationWorkOrdersController#create: 创建失败，错误: #{@communication_work_order.errors.full_messages.inspect}"
        Rails.logger.error "CommunicationWorkOrdersController#create: 工单状态: #{@communication_work_order.status}, 处理意见: #{@communication_work_order.processing_opinion}"
        Rails.logger.error "CommunicationWorkOrdersController#create: 费用类型ID: #{@communication_work_order.fee_type_id}, 问题类型IDs: #{@communication_work_order.problem_type_ids}"
        # Re-fetch reimbursement if save fails, needed for the form on render :new
        @reimbursement = Reimbursement.find_by(id: create_params[:reimbursement_id])
        
        # 重新设置费用明细IDs
        if create_params[:submitted_fee_detail_ids].present?
          @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, create_params[:submitted_fee_detail_ids])
          @communication_work_order.submitted_fee_detail_ids = create_params[:submitted_fee_detail_ids]
        end
        
        # 重新设置问题类型IDs
        if create_params[:problem_type_ids].present?
          @communication_work_order.problem_type_ids = create_params[:problem_type_ids]
        end
        
        flash.now[:error] = "创建沟通工单失败: #{@communication_work_order.errors.full_messages.join(', ')}"
        render :new
      end
    end

    def update
      @communication_work_order = CommunicationWorkOrder.find(params[:id])
      service = CommunicationWorkOrderService.new(@communication_work_order, current_admin_user)
      
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

      if service.update(update_params.except(:submitted_fee_detail_ids, :problem_type_ids)) # Pass params without arrays to service
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
        :fee_type_id,
        :audit_comment,
        :remark,
        submitted_fee_detail_ids: [],
        problem_type_ids: []
      )
    end
  end

  # Temporarily disable filters to fix the "First argument in form cannot contain nil or be empty" error
  # filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  # filter :status, as: :select, collection: -> { CommunicationWorkOrder.state_machine(:status).states.map(&:value) }
  # filter :audit_comment
  # filter :problem_type_id, as: :select, collection: -> { ProblemType.all.map { |pt| [pt.name, pt.id] } }
  # filter :creator
  # filter :created_at
  
  # Disable filters completely
  config.filters = false

  # Scopes
  scope :all, default: true
  scope :pending
  scope :approved
  scope :rejected
  scope :completed

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
            
            # 两级级联下拉选择
            f.input :fee_type_id, as: :select,
                    collection: FeeType.active.order(:code).map { |ft| [ft.display_name, ft.id] },
                    include_blank: '请选择费用类型',
                    input_html: { id: 'fee_type_select' },
                    wrapper_html: { id: 'fee_type_row', style: 'display:none;' }
            
            # 注意：问题类型现在通过费用明细选择部分的复选框选择，不再使用下拉框
            # 保留此字段以兼容旧代码，但设置为隐藏
            f.input :problem_type_id, as: :hidden,
                    input_html: { id: 'problem_type_select' }
            
            # 添加说明
            f.inputs '问题类型', id: 'problem_type_row', style: 'display:none;' do
              para "请在费用明细选择区域中选择问题类型"
            end
            
            # Order: 4. 审核意见 (Conditionally Visible)
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
            const feeTypeRow = document.getElementById('fee_type_row');
            const problemTypeRow = document.getElementById('problem_type_row');
            const auditCommentRow = document.getElementById('communication_audit_comment_row');
            const remarkRow = document.getElementById('communication_remark_row');
            
            const feeTypeSelect = document.getElementById('fee_type_select');
            const problemTypeSelect = document.getElementById('problem_type_select');
            
            // 初始化问题类型下拉框
            function updateProblemTypes() {
              const feeTypeId = feeTypeSelect.value;
              
              console.log('Updating problem types for fee type ID:', feeTypeId);
              
              // 清空当前选项
              problemTypeSelect.innerHTML = '<option value=\"\">请选择问题类型</option>';
              
              if (!feeTypeId) {
                console.log('No fee type ID selected, not fetching problem types');
                return;
              }
              
              // 获取对应的问题类型
              console.log('Fetching problem types for fee type ID:', feeTypeId);
              fetch('/admin/problem_types.json?fee_type_id=' + feeTypeId)
                .then(response => response.json())
                .then(data => {
                  console.log('Received problem types:', data);
                  data.forEach(problemType => {
                    const option = document.createElement('option');
                    option.value = problemType.id;
                    option.textContent = problemType.display_name;
                    problemTypeSelect.appendChild(option);
                  });
                })
                .catch(error => console.error('Error fetching problem types:', error));
            }
            
            // 切换字段显示
            function toggleFields() {
              if (!processingOpinionSelect || !feeTypeRow || !problemTypeRow || !auditCommentRow || !remarkRow) {
                console.warn('One or more conditional fields not found for CommunicationWorkOrder form.');
                return;
              }
              const selectedValue = processingOpinionSelect.value;
              console.log('Processing opinion selected:', selectedValue);

              feeTypeRow.style.display = 'none';
              problemTypeRow.style.display = 'none';
              auditCommentRow.style.display = 'none';
              remarkRow.style.display = 'none';

              if (selectedValue === '无法通过') {
                console.log('Showing fee type, problem type, audit comment, and remark fields');
                feeTypeRow.style.display = 'list-item';
                problemTypeRow.style.display = 'list-item';
                auditCommentRow.style.display = 'list-item';
                remarkRow.style.display = 'list-item';
              } else if (selectedValue === '可以通过') {
                console.log('Showing audit comment and remark fields');
                auditCommentRow.style.display = 'list-item';
                remarkRow.style.display = 'list-item';
              } else {
                console.log('Showing audit comment and remark fields (default)');
                auditCommentRow.style.display = 'list-item';
                remarkRow.style.display = 'list-item';
              }
            }

            // 设置事件监听器
            if (processingOpinionSelect) {
              processingOpinionSelect.addEventListener('change', toggleFields);
              toggleFields();
            } else {
              console.warn('Processing opinion select not found for CommunicationWorkOrder form.');
            }
            
            if (feeTypeSelect) {
              feeTypeSelect.addEventListener('change', updateProblemTypes);
              // 初始加载
              updateProblemTypes();
            }
          });
          
          // Add form submission handler
          document.addEventListener('submit', function(event) {
            if (event.target.id === 'new_communication_work_order' || event.target.id.startsWith('edit_communication_work_order')) {
              console.log('Form submission detected');
              
              // Log form data
              const formData = new FormData(event.target);
              const formDataObj = {};
              formData.forEach((value, key) => {
                formDataObj[key] = value;
              });
              console.log('Form data:', formDataObj);
              
              // Check processing opinion
              const processingOpinion = formData.get('communication_work_order[processing_opinion]');
              console.log('Processing opinion:', processingOpinion);
              
              // Check fee type ID
              const feeTypeId = formData.get('communication_work_order[fee_type_id]');
              console.log('Fee type ID:', feeTypeId);
              
              // Check problem type ID
              const problemTypeId = formData.get('communication_work_order[problem_type_id]');
              console.log('Problem type ID:', problemTypeId);
              
              // If processing opinion is '无法通过' but fee_type_id or problem_type_id is missing, show an alert
              if (processingOpinion === '无法通过' && (!feeTypeId || !problemTypeId)) {
                console.error('Validation error: When processing opinion is 无法通过, fee_type_id and problem_type_id are required');
                // Skip the alert for now as it's causing syntax issues
                event.preventDefault();
              }
            }
          });
        """
      end
    end
  end
end