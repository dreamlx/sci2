ActiveAdmin.register CommunicationWorkOrder do
  permit_params :reimbursement_id, :audit_comment, # creator_id by controller, audit_date by system
                # Shared fields
                :remark, :processing_opinion,
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
      CommunicationWorkOrder.includes(:reimbursement, :creator, :problem_types, :fee_details)
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
      _communication_work_order_params = params.require(:communication_work_order).permit(
        :reimbursement_id, :audit_comment, # creator_id by controller, audit_date by system
        :remark, :processing_opinion,
        submitted_fee_detail_ids: [], problem_type_ids: []
      )
      
      Rails.logger.debug "CommunicationWorkOrdersController#create: 参数: #{_communication_work_order_params.inspect}"

      # 创建工单实例
      @communication_work_order = CommunicationWorkOrder.new(_communication_work_order_params.except(:submitted_fee_detail_ids, :problem_type_ids))
      @communication_work_order.created_by = current_admin_user.id
      
      Rails.logger.debug "CommunicationWorkOrdersController#create: 创建工单实例: #{@communication_work_order.inspect}"

      # 处理费用明细IDs
      if _communication_work_order_params[:submitted_fee_detail_ids].present?
        Rails.logger.debug "CommunicationWorkOrdersController#create: 设置费用明细IDs: #{_communication_work_order_params[:submitted_fee_detail_ids].inspect}"
        @communication_work_order.instance_variable_set(:@_direct_submitted_fee_ids, _communication_work_order_params[:submitted_fee_detail_ids])
        @communication_work_order.submitted_fee_detail_ids = _communication_work_order_params[:submitted_fee_detail_ids]
      else
        Rails.logger.debug "CommunicationWorkOrdersController#create: 没有提供费用明细IDs"
      end
      
      # 设置问题类型IDs
      if _communication_work_order_params[:problem_type_ids].present?
        Rails.logger.debug "CommunicationWorkOrdersController#create: 设置问题类型IDs: #{_communication_work_order_params[:problem_type_ids].inspect}"
        @communication_work_order.problem_type_ids = _communication_work_order_params[:problem_type_ids]
      else
        Rails.logger.debug "CommunicationWorkOrdersController#create: 没有提供问题类型IDs"
      end
      
      if @communication_work_order.save
        Rails.logger.debug "CommunicationWorkOrdersController#create: 创建成功，重定向到详情页"
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已成功创建"
      else
        Rails.logger.error "CommunicationWorkOrdersController#create: 创建失败，错误: #{@communication_work_order.errors.full_messages.inspect}"
        Rails.logger.error "CommunicationWorkOrdersController#create: 工单状态: #{@communication_work_order.status}, 处理意见: #{@communication_work_order.processing_opinion}"
        # Re-fetch reimbursement if save fails, needed for the form on render :new
        @reimbursement = Reimbursement.find_by(id: _communication_work_order_params[:reimbursement_id])
        
        # 重新设置费用明细IDs
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
    column "问题类型", :problem_types do |wo| 
      if wo.problem_types.any?
        wo.problem_types.map(&:display_name).join(", ")
      else
        # 兼容旧数据
        wo.problem_type&.name
      end
    end
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
    
    if resource.reimbursement.present?
      render 'admin/reimbursements/reimbursement_display', reimbursement: resource.reimbursement
    end

    attributes_table do
      row :id
      row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) if wo.reimbursement end
      row :status do |wo| status_tag wo.status end
      row :processing_opinion
      row "审核意见", :audit_comment
      row :creator
      row :created_at
      row :updated_at
    end


    panel "关联的费用明细" do
      if resource.fee_details.any?
        table_for resource.fee_details do
          column "ID" do |fee_detail|
            link_to fee_detail.id, admin_fee_detail_path(fee_detail)
          end
          column "费用类型" do |fee_detail|
            fee_detail.fee_type.to_s
          end
          column "金额" do |fee_detail|
            number_to_currency(fee_detail.amount, unit: "¥")
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
          column "操作" do |fee_detail|
            if resource.editable?
              link_to "验证", verify_fee_detail_admin_communication_work_order_path(resource, fee_detail_id: fee_detail.id)
            end
          end
        end
      else
        para "此工单未关联任何费用明细"
      end
    end
    
    # 问题类型面板 - 按费用类型分组显示
    panel "问题类型详情" do
      if resource.problem_types.any?
        # 按费用类型分组问题类型
        grouped_problem_types = resource.problem_types.group_by { |pt| pt.fee_type_id }
        
        div do
          grouped_problem_types.each do |fee_type_id, problem_types|
            fee_type = FeeType.find_by(id: fee_type_id)
            fee_type_name = fee_type ? fee_type.display_name : "未分类"
            
            h4 do
              if fee_type
                link_to(fee_type_name, admin_fee_type_path(fee_type))
              else
                text_node fee_type_name
              end
            end
            
            ul do
              problem_types.each do |problem_type|
                li do
                  link_to problem_type.display_name, admin_problem_type_path(problem_type)
                end
              end
            end
            
            hr
          end
        end
      else
        para "此工单未关联任何问题类型"
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
            render 'admin/shared/fee_details_selection', work_order: f.object, reimbursement: reimbursement, param_name: 'communication_work_order'
          else
            f.inputs '费用明细' do
              para "无法加载费用明细，未关联有效的报销单。"
            end
          end

          f.inputs '处理与反馈' do
            # 处理意见
            f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all, include_blank: '请选择处理意见', input_html: { id: 'communication_work_order_processing_opinion' }
            
            # 审核意见
            f.input :audit_comment, label: "审核意见", 
                    input_html: { id: 'audit_comment_field' },
                    wrapper_html: { id: 'communication_audit_comment_row', style: 'display:none;' }
            
            # 备注
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
            const auditCommentRow = document.getElementById('communication_audit_comment_row');
            const remarkRow = document.getElementById('communication_remark_row');
            const problemTypesContainer = document.getElementById('problem-types-container');
            const feeTypeTagsContainer = document.getElementById('fee-type-tags');
            
            // 切换字段显示
            function toggleFields() {
              if (!processingOpinionSelect || !auditCommentRow || !remarkRow) {
                console.warn('One or more conditional fields not found for CommunicationWorkOrder form.');
                return;
              }
              
              const selectedValue = processingOpinionSelect.value;
              console.log('Processing opinion selected:', selectedValue);

              // 默认隐藏所有字段
              auditCommentRow.style.display = 'none';
              remarkRow.style.display = 'none';
              
              // 根据处理意见显示相应字段
              if (selectedValue === '无法通过') {
                console.log('Showing problem types, audit comment, and remark fields');
                if (problemTypesContainer) {
                  problemTypesContainer.style.display = 'block';
                }
                auditCommentRow.style.display = 'list-item';
                remarkRow.style.display = 'list-item';
              } else if (selectedValue === '可以通过') {
                console.log('Showing audit comment and hiding problem types');
                if (problemTypesContainer) {
                  problemTypesContainer.style.display = 'none';
                }
                auditCommentRow.style.display = 'list-item';
                remarkRow.style.display = 'list-item';
              } else {
                console.log('Hiding all conditional fields');
                if (problemTypesContainer) {
                  problemTypesContainer.style.display = 'none';
                }
              }
            }

            // 设置事件监听器
            if (processingOpinionSelect) {
              processingOpinionSelect.addEventListener('change', toggleFields);
              // 初始化显示状态
              toggleFields();
            } else {
              console.warn('Processing opinion select not found for CommunicationWorkOrder form.');
            }
            
            // 监听费用明细复选框变化
            const feeDetailCheckboxes = document.querySelectorAll('.fee-detail-checkbox');
            if (feeDetailCheckboxes.length > 0) {
              feeDetailCheckboxes.forEach(checkbox => {
                checkbox.addEventListener('change', function() {
                  updateSelectedFeeDetails();
                  updateFeeTypeTags();
                  loadProblemTypes();
                });
              });
              
              // 初始化
              updateSelectedFeeDetails();
              updateFeeTypeTags();
              loadProblemTypes();
            }
            
            // 存储选中的费用明细
            let selectedFeeDetails = [];
            // 存储费用类型分组
            let feeTypeGroups = {};
            
            // 更新选中的费用明细
            function updateSelectedFeeDetails() {
              selectedFeeDetails = [];
              feeTypeGroups = {};
              
              feeDetailCheckboxes.forEach(checkbox => {
                if (checkbox.checked) {
                  const feeDetailId = checkbox.value;
                  const feeType = checkbox.dataset.feeType;
                  
                  selectedFeeDetails.push({
                    id: feeDetailId,
                    feeType: feeType
                  });
                  
                  // 按费用类型分组
                  if (!feeTypeGroups[feeType]) {
                    feeTypeGroups[feeType] = [];
                  }
                  feeTypeGroups[feeType].push(feeDetailId);
                }
              });
            }
            
            // 更新费用类型标签
            function updateFeeTypeTags() {
              if (!feeTypeTagsContainer) return;
              
              feeTypeTagsContainer.innerHTML = '';
              
              if (Object.keys(feeTypeGroups).length === 0) {
                feeTypeTagsContainer.innerHTML = '<p>未选择费用明细</p>';
                if (problemTypesContainer) {
                  problemTypesContainer.style.display = 'none';
                }
                return;
              }
              
              for (const feeType in feeTypeGroups) {
                const tagDiv = document.createElement('div');
                tagDiv.className = 'fee-type-tag';
                tagDiv.dataset.feeType = feeType;
                tagDiv.textContent = `${feeType} (${feeTypeGroups[feeType].length}项)`;
                feeTypeTagsContainer.appendChild(tagDiv);
              }
            }
            
            // 加载问题类型
            function loadProblemTypes() {
              if (!problemTypesContainer) return;
              
              const problemTypesWrapper = problemTypesContainer.querySelector('.problem-types-wrapper');
              if (!problemTypesWrapper) return;
              
              problemTypesWrapper.innerHTML = '';
              
              if (Object.keys(feeTypeGroups).length === 0) {
                return;
              }
              
              // 获取所有费用类型名称
              const feeTypeNames = Object.keys(feeTypeGroups);
              
              // 查询每个费用类型对应的问题类型
              Promise.all(feeTypeNames.map(feeTypeName => {
                return fetch(`/admin/fee_types.json?title=${encodeURIComponent(feeTypeName)}`)
                  .then(response => response.json())
                  .then(feeTypes => {
                    if (feeTypes.length > 0) {
                      const feeTypeId = feeTypes[0].id;
                      return fetch(`/admin/problem_types.json?fee_type_id=${feeTypeId}`)
                        .then(response => response.json())
                        .then(problemTypes => {
                          return {
                            feeTypeName,
                            feeTypeId,
                            problemTypes
                          };
                        });
                    }
                    return {
                      feeTypeName,
                      feeTypeId: null,
                      problemTypes: []
                    };
                  });
              }))
              .then(results => {
                results.forEach(result => {
                  if (result.problemTypes.length > 0) {
                    // 创建费用类型分组
                    const sectionDiv = document.createElement('div');
                    sectionDiv.className = 'problem-type-section';
                    
                    // 创建费用类型标题
                    const feeTypeTitle = document.createElement('h5');
                    feeTypeTitle.textContent = result.feeTypeName;
                    sectionDiv.appendChild(feeTypeTitle);
                    
                    // 创建问题类型复选框容器
                    const checkboxContainer = document.createElement('div');
                    checkboxContainer.className = 'problem-type-checkboxes';
                    
                    result.problemTypes.forEach(problemType => {
                      const checkboxDiv = document.createElement('div');
                      checkboxDiv.className = 'problem-type-checkbox';
                      
                      const checkbox = document.createElement('input');
                      checkbox.type = 'checkbox';
                      checkbox.id = `problem_type_${problemType.id}`;
                      checkbox.name = 'communication_work_order[problem_type_ids][]';
                      checkbox.value = problemType.id;
                      
                      const label = document.createElement('label');
                      label.htmlFor = `problem_type_${problemType.id}`;
                      label.textContent = problemType.display_name;
                      
                      checkboxDiv.appendChild(checkbox);
                      checkboxDiv.appendChild(label);
                      checkboxContainer.appendChild(checkboxDiv);
                    });
                    
                    sectionDiv.appendChild(checkboxContainer);
                    problemTypesWrapper.appendChild(sectionDiv);
                  }
                });
                
                // 根据处理意见显示或隐藏问题类型
                toggleFields();
              })
              .catch(error => console.error('Error loading problem types:', error));
            }
          });
        """
      end
    end
  end
end