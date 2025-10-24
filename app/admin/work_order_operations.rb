# app/admin/work_order_operations.rb
ActiveAdmin.register WorkOrderOperation do
  # Menu configuration
  menu false # Hide from main menu

  # Belongs to configuration - using polymorphic relationship for STI
  belongs_to :audit_work_order, optional: true, polymorphic: true
  belongs_to :communication_work_order, optional: true, polymorphic: true
  belongs_to :express_receipt_work_order, optional: true, polymorphic: true

  # Actions configuration
  actions :index, :show # Read-only

  # Controller customization
  controller do
    def scoped_collection
      super.includes(:work_order, :admin_user)
    end

    # Override to handle STI
    def find_resource
      scoped_collection.find(params[:id])
    end

    # Override to handle STI
    def find_collection
      collection = super
      collection = collection.where(work_order_id: params[:audit_work_order_id]) if params[:audit_work_order_id]
      if params[:communication_work_order_id]
        collection = collection.where(work_order_id: params[:communication_work_order_id])
      end
      if params[:express_receipt_work_order_id]
        collection = collection.where(work_order_id: params[:express_receipt_work_order_id])
      end
      collection
    end
  end

  # Filters
  filter :work_order
  filter :admin_user
  filter :operation_type, as: :select, collection: lambda {
    WorkOrderOperation.operation_types.map do |type|
      [WorkOrderOperation.new(operation_type: type).operation_type_display, type]
    end
  }
  filter :created_at

  # Index page
  index do
    selectable_column
    id_column
    column :work_order do |operation|
      work_order = operation.work_order
      case work_order.type
      when 'AuditWorkOrder'
        link_to "审核工单 ##{work_order.id}", admin_audit_work_order_path(work_order)
      when 'CommunicationWorkOrder'
        link_to "沟通工单 ##{work_order.id}", admin_communication_work_order_path(work_order)
      when 'ExpressReceiptWorkOrder'
        link_to "快递收单工单 ##{work_order.id}", admin_express_receipt_work_order_path(work_order)
      else
        "工单 ##{work_order.id}"
      end
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
    actions
  end

  # Show page
  show do
    attributes_table do
      row :id
      row :work_order do |operation|
        work_order = operation.work_order
        case work_order.type
        when 'AuditWorkOrder'
          link_to "审核工单 ##{work_order.id}", admin_audit_work_order_path(work_order)
        when 'CommunicationWorkOrder'
          link_to "沟通工单 ##{work_order.id}", admin_communication_work_order_path(work_order)
        when 'ExpressReceiptWorkOrder'
          link_to "快递收单工单 ##{work_order.id}", admin_express_receipt_work_order_path(work_order)
        else
          "工单 ##{work_order.id}"
        end
      end
      row :operation_type do |operation|
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
      row :admin_user
      row :created_at
    end

    panel '操作详情' do
      attributes_table_for resource do
        row :details do |operation|
          pre code JSON.pretty_generate(operation.details_hash)
        end
      end
    end

    panel '状态变化' do
      tabs do
        tab '操作前' do
          attributes_table_for resource do
            row :previous_state do |operation|
              pre code JSON.pretty_generate(operation.previous_state_hash)
            end
          end
        end

        tab '操作后' do
          attributes_table_for resource do
            row :current_state do |operation|
              pre code JSON.pretty_generate(operation.current_state_hash)
            end
          end
        end

        tab '差异对比' do
          if resource.previous_state.present? && resource.current_state.present?
            div class: 'state-diff' do
              state_diff(resource.previous_state, resource.current_state)
            end
          else
            para '无法生成差异对比，操作前或操作后的状态为空。'
          end
        end
      end
    end
  end

  # Sidebar
  sidebar '相关信息', only: :show do
    attributes_table_for resource do
      row '工单类型' do |operation|
        operation.work_order.type
      end
      row '工单状态' do |operation|
        status_tag operation.work_order.status
      end
      row '报销单' do |operation|
        if operation.work_order.reimbursement
          link_to operation.work_order.reimbursement.invoice_number,
                  admin_reimbursement_path(operation.work_order.reimbursement)
        else
          '无关联报销单'
        end
      end
    end
  end
end
