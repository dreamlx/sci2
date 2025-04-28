ActiveAdmin.register CommunicationWorkOrder do
  permit_params :reimbursement_id, :audit_work_order_id, :status, :communication_method,
                :initiator_role, :resolution_summary, :created_by,
                # 共享字段 (Req 6/7)
                :problem_type, :problem_description, :remark, :processing_opinion,
                fee_detail_ids: []

  menu priority: 4, label: "沟通工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'

  controller do
    def scoped_collection
      CommunicationWorkOrder.includes(:reimbursement, :creator, :audit_work_order)
    end

    # 创建时设置报销单/审核工单ID
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # 根据Req 5/7要求，沟通工单需要关联审核工单
      if params[:audit_work_order_id] && resource.audit_work_order_id.nil?
         resource.audit_work_order_id = params[:audit_work_order_id]
      end
      resource
    end
  end

  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :audit_work_order_id
  filter :status, as: :select, collection: CommunicationWorkOrder.state_machines[:status].states.map(&:value)
  filter :communication_method
  filter :initiator_role
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
    link_to "开始处理", start_processing_admin_communication_work_order_path(resource), method: :put, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :mark_needs_communication, only: :show, if: proc { resource.pending? } do
    link_to "标记需沟通", mark_needs_communication_admin_communication_work_order_path(resource), method: :put, data: { confirm: "确定要标记为需要沟通吗?" }
  end
  action_item :approve, only: :show, if: proc { resource.processing? || resource.needs_communication? } do
    link_to "沟通后通过", approve_admin_communication_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? || resource.needs_communication? } do
    link_to "沟通后拒绝", reject_admin_communication_work_order_path(resource)
  end
  action_item :add_communication_record, only: :show do
    link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource)
  end

  # 成员操作
  member_action :start_processing, method: :put do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.start_processing
      redirect_to admin_communication_work_order_path(resource), notice: "工单已开始处理"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :mark_needs_communication, method: :put do
     service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.mark_needs_communication
      redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为需要沟通"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
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
      @fee_detail = resource.fee_details.find(params[:fee_detail_id])
      render 'admin/shared/verify_fee_detail'
   end

   member_action :do_verify_fee_detail, method: :post do
     service = CommunicationWorkOrderService.new(resource, current_admin_user)
     if service.update_fee_detail_verification(params[:fee_detail_id], params[:verification_status], params[:comment])
        redirect_to admin_communication_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
     else
        @work_order = resource
        @fee_detail = resource.fee_details.find(params[:fee_detail_id])
        flash.now[:alert] = "费用明细 ##{params[:fee_detail_id]} 更新失败: #{@fee_detail.errors.full_messages.join(', ')}"
        render 'admin/shared/verify_fee_detail'
     end
   end

  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :audit_work_order do |wo| link_to wo.audit_work_order_id, admin_audit_work_order_path(wo.audit_work_order) if wo.audit_work_order_id end
    column :status do |wo| status_tag wo.status end
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
           row :audit_work_order do |wo| link_to wo.audit_work_order_id, admin_audit_work_order_path(wo.audit_work_order) if wo.audit_work_order_id end
           row :type
           row :status do |wo| status_tag wo.status end
           row :communication_method
           row :initiator_role
           row :resolution_summary
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

       tab "费用明细 (#{resource.fee_details.count})" do
          panel "费用明细信息" do
            table_for resource.fee_detail_selections.includes(:fee_detail) do |selection|
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
            table_for resource.work_order_status_changes.order(changed_at: :desc) do
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

  # 表单
  form do |f|
    f.inputs "沟通工单信息" do
      if f.object.new_record?
        f.input :reimbursement_id, as: :select,
                    collection: Reimbursement.all.map { |r| ["#{r.invoice_number} - #{r.applicant}", r.id] },
                    input_html: { disabled: !f.object.new_record? }

        if f.object.reimbursement_id.present?
          f.input :audit_work_order_id, as: :select,
                      collection: AuditWorkOrder.where(reimbursement_id: f.object.reimbursement_id)
                                              .map { |wo| ["审核工单 ##{wo.id} (#{wo.status})", wo.id] },
                      include_blank: "-- 选择关联的审核工单 --"
        else
          li class: "string input" do
            label "审核工单"
            p class: "inline-hints", do: "请先选择报销单，然后才能选择关联的审核工单"
          end
        end
      else
        f.input :reimbursement_id, as: :hidden
        li class: "string input" do
          label "报销单"
          span link_to f.object.reimbursement.invoice_number, admin_reimbursement_path(f.object.reimbursement)
        end

        f.input :audit_work_order_id, as: :hidden
        if f.object.audit_work_order_id.present?
          li class: "string input" do
            label "审核工单"
            span link_to "审核工单 ##{f.object.audit_work_order_id}", admin_audit_work_order_path(f.object.audit_work_order)
          end
        end
      end

      if f.object.new_record?
        f.input :problem_type, as: :select, collection: ProblemTypeOptions.all
        f.input :problem_description, as: :select, collection: ProblemDescriptionOptions.all
        f.input :remark, as: :text, input_html: { rows: 3 }
        f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all
        f.input :communication_method, as: :select, collection: CommunicationMethodOptions.all
        f.input :initiator_role, as: :select, collection: InitiatorRoleOptions.all
      else
        f.input :problem_type
        f.input :problem_description
        f.input :remark
        f.input :processing_opinion
        f.input :communication_method
        f.input :initiator_role

        if f.object.status == 'approved' || f.object.status == 'rejected'
          f.input :resolution_summary
        end
      end
    end

    if f.object.new_record?
      f.inputs "选择费用明细" do
        if f.object.reimbursement_id.present?
          div class: "fee-detail-selection" do
            div class: "select-actions" do
              a "全选", href: "#", class: "select-all"
              text_node " | "
              a "取消全选", href: "#", class: "deselect-all"
            end

            table class: "fee-details-table" do
              thead do
                tr do
                  th class: "selectable"
                  th "ID"
                  th "费用类型"
                  th "金额"
                  th "费用日期"
                  th "验证状态"
                end
              end
              tbody do
                f.object.reimbursement.fee_details.each do |fee_detail|
                  tr do
                    td do
                      check_box_tag "communication_work_order[fee_detail_ids][]", fee_detail.id,
                                       f.object.fee_detail_ids.include?(fee_detail.id)
                    end
                    td fee_detail.id
                    td fee_detail.fee_type
                    td number_to_currency(fee_detail.amount, unit: "¥")
                    td fee_detail.fee_date
                    td status_tag fee_detail.verification_status
                  end
                end
              end
            end

            script do
              raw "$(document).ready(function() {
                $('.select-all').click(function(e) {
                  e.preventDefault();
                  $('.fee-details-table input[type=\"checkbox\"]').prop('checked', true);
                });

                $('.deselect-all').click(function(e) {
                  e.preventDefault();
                  $('.fee-details-table input[type=\"checkbox\"]').prop('checked', false);
                });

                // 动态加载审核工单
                $('#communication_work_order_reimbursement_id').change(function() {
                  var reimbursementId = $(this).val();
                  if (reimbursementId) {
                    $.get('/admin/audit_work_orders.json?q[reimbursement_id_eq]=' + reimbursementId, function(data) {
                      var options = '<option value=\"\">-- 选择关联的审核工单 --</option>';
                      $.each(data, function(index, workOrder) {
                        options += '<option value=\"' + workOrder.id + '\">审核工单 #' + workOrder.id + ' (' + workOrder.status + ')</option>';
                      });
                      $('#communication_work_order_audit_work_order_id').html(options);
                    });
                  } else {
                    $('#communication_work_order_audit_work_order_id').html('<option value=\"\">-- 选择关联的审核工单 --</option>');
                  }
                });
              });"
            end
          end

        else
          p "请先选择报销单，然后才能选择费用明细。"
        end
      end
    end

    f.actions
  end
end