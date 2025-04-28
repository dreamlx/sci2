# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "报销单状态统计" do
          div class: "dashboard-stats" do
            ul do
              li do
                span "待处理", class: "stat-label"
                span Reimbursement.pending.count, class: "stat-value pending"
              end
              li do
                span "处理中", class: "stat-label"
                span Reimbursement.processing.count, class: "stat-value processing"
              end
              li do
                span "等待完成", class: "stat-label"
                span Reimbursement.waiting_completion.count, class: "stat-value waiting"
              end
              li do
                span "已关闭", class: "stat-label"
                span Reimbursement.closed.count, class: "stat-value closed"
              end
            end
          end
        end
      end
      
      column do
        panel "工单状态统计" do
          div class: "dashboard-stats" do
            ul do
              li do
                span "待处理审核工单", class: "stat-label"
                span AuditWorkOrder.pending.count, class: "stat-value pending"
              end
              li do
                span "处理中审核工单", class: "stat-label"
                span AuditWorkOrder.processing.count, class: "stat-value processing"
              end
              li do
                span "待处理沟通工单", class: "stat-label"
                span CommunicationWorkOrder.pending.count, class: "stat-value pending"
              end
              li do
                span "需要沟通工单", class: "stat-label"
                span CommunicationWorkOrder.needs_communication.count, class: "stat-value needs-communication"
              end
            end
          end
        end
      end
    end
    
    columns do
      column do
        panel "待处理工作" do
          table_for AuditWorkOrder.pending.order(created_at: :desc).limit(5) do
            column("报销单") { |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) }
            column("类型") { |wo| "审核工单" }
            column("状态") { |wo| status_tag wo.status }
            column("创建时间") { |wo| wo.created_at.strftime('%Y-%m-%d %H:%M') }
            column("操作") { |wo| link_to "处理", admin_audit_work_order_path(wo) }
          end
          
          table_for CommunicationWorkOrder.pending.order(created_at: :desc).limit(5) do
            column("报销单") { |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) }
            column("类型") { |wo| "沟通工单" }
            column("状态") { |wo| status_tag wo.status }
            column("创建时间") { |wo| wo.created_at.strftime('%Y-%m-%d %H:%M') }
            column("操作") { |wo| link_to "处理", admin_communication_work_order_path(wo) }
          end
          
          div do
            link_to "查看所有待处理工单", admin_audit_work_orders_path(q: {status_eq: 'pending'}), class: "button"
          end
        end
      end
      
      column do
        panel "最近活动" do
          table_for WorkOrderStatusChange.order(changed_at: :desc).limit(10) do
            column("工单") do |change| 
              if change.work_order
                link_to "#{change.work_order.class.name.underscore.humanize} ##{change.work_order.id}", 
                        polymorphic_path([:admin, change.work_order])
              else
                "已删除工单"
              end
            end
            column("状态变更") { |change| "#{change.from_status} → #{change.to_status}" }
            column("操作人") { |change| change.changer&.email || "系统" }
            column("时间") { |change| change.changed_at.strftime('%Y-%m-%d %H:%M') }
          end
        end
      end
    end
    
    panel "数据导入" do
      div class: "import-buttons" do
        span do
          link_to "导入报销单", new_import_admin_reimbursements_path, class: "button"
        end
        span do
          link_to "导入快递收单", new_import_admin_express_receipt_work_orders_path, class: "button"
        end
        span do
          link_to "导入费用明细", new_import_admin_fee_details_path, class: "button"
        end
        span do
          link_to "导入操作历史", new_import_admin_operation_histories_path, class: "button"
        end
      end
    end
  end # content
end
