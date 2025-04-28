ActiveAdmin.register AuditWorkOrder do
  permit_params :reimbursement_id, :status, :audit_result, :audit_comment, :audit_date,
                :vat_verified, :created_by,
                # 共享字段 (Req 6/7)
                :problem_type, :problem_description, :remark, :processing_opinion,
                fee_detail_ids: []

  menu priority: 3, label: "审核工单", parent: "工单管理"
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
      resource
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

  # 操作按钮
  action_item :start_processing, only: :show, if: proc { resource.pending? } do
    link_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :put, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :approve, only: :show, if: proc { resource.processing? } do
    link_to "审核通过", approve_admin_audit_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? } do
    link_to "审核拒绝", reject_admin_audit_work_order_path(resource)
  end

  # 成员操作
  member_action :start_processing, method: :put do
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
     @fee_detail = resource.fee_details.find(params[:fee_detail_id])
     render 'admin/shared/verify_fee_detail' # 渲染 app/views/admin/shared/verify_fee_detail.html.erb
  end

  member_action :do_verify_fee_detail, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    # 直接使用参数，不需要嵌套在audit_work_order下
    if service.update_fee_detail_verification(params[:fee_detail_id], params[:verification_status], params[:comment])
       redirect_to admin_audit_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
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
              link_to("更新验证状态", verify_fee_detail_admin_audit_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
            end
          end
        end
      end

      tab "沟通工单 (#{resource.communication_work_orders.count})" do
         panel "关联沟通工单" do
            table_for resource.communication_work_orders do
                column(:id) { |comm_wo| link_to comm_wo.id, admin_communication_work_order_path(comm_wo) }
                column(:status) { |comm_wo| status_tag comm_wo.status }
                column :creator
                column :created_at
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
    f.inputs "审核工单信息" do
      if f.object.new_record?
        f.input :reimbursement_id, as: :select,
                    collection: Reimbursement.all.map { |r| ["#{r.invoice_number} - #{r.applicant}", r.id] },
                    input_html: { disabled: !f.object.new_record? }
      else
        f.input :reimbursement_id, as: :hidden
        li class: "string input" do
          label "报销单"
          span link_to f.object.reimbursement.invoice_number, admin_reimbursement_path(f.object.reimbursement)
        end
      end

      if f.object.new_record?
        f.input :problem_type, as: :select, collection: ProblemTypeOptions.all
        f.input :problem_description, as: :select, collection: ProblemDescriptionOptions.all
        f.input :remark, as: :text, input_html: { rows: 3 }
        f.input :processing_opinion, as: :select, collection: ProcessingOpinionOptions.all
      else
        f.input :problem_type
        f.input :problem_description
        f.input :remark
        f.input :processing_opinion
      end

      if !f.object.new_record? && f.object.audit_result.present?
        f.input :audit_result, input_html: { disabled: true }
        f.input :audit_comment
        f.input :audit_date, as: :datepicker
        f.input :vat_verified
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
                      check_box_tag "audit_work_order[fee_detail_ids][]", fee_detail.id,
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