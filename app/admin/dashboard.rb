ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "系统概览" do
          div class: 'dashboard-stats' do
            div class: 'stat-box' do
              h4 "报销单总数"
              h3 Reimbursement.count
            end

            div class: 'stat-box' do
              h4 "工单总数"
              h3 WorkOrder.count
            end

            div class: 'stat-box' do
              h4 "费用明细总数"
              h3 FeeDetail.count
            end

            div class: 'stat-box' do
              h4 "已验证费用明细"
              h3 FeeDetail.where(verification_status: 'verified').count
            end
          end
        end
        
        panel "系统操作" do
          div class: 'dashboard-stats' do
            div class: 'stat-box' do
              p "导入报销单"
              a href: new_import_admin_reimbursements_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入报销单'
              end
            end

            div class: 'stat-box' do
              p "导入费用明细"
              a href: new_import_admin_fee_details_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入费用明细'
              end
            end

            div class: 'stat-box' do
              p "导入快递收单"
              a href: new_import_admin_express_receipt_work_orders_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入快递收单'
              end
            end

            div class: 'stat-box' do
              p "导入操作历史"
              a href: operation_histories_admin_imports_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入操作历史'
              end
            end
            
            div class: 'stat-box' do
              p "分配报销单"
              a href: admin_reimbursements_path(scope: 'unassigned'), class: 'import-button' do
                i class: 'fa fa-user-plus fa-3x', 'data-label': '分配报销单'
              end
            end
            
            div class: 'stat-box' do
              p "查看分配给我的报销单"
              a href: "/admin/reimbursements?scope=my_assignments", class: 'import-button' do
                i class: 'fa fa-tasks fa-3x', 'data-label': '查看分配给我的报销单'
              end
            end
          end
        end

      end

      column do
        panel "待处理审核工单" do
          table_for AuditWorkOrder.pending.includes(:reimbursement).order(created_at: :desc).limit(10) do
            column("ID") { |wo| link_to(wo.id, admin_audit_work_order_path(wo)) }
            column("报销单") { |wo| link_to(wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement)) }
            column("问题类型") { |wo| wo.problem_type&.display_name }
            column("创建时间") { |wo| wo.created_at.strftime("%Y-%m-%d %H:%M") }
          end
          div class: 'panel-footer' do
            link_to "查看全部", admin_audit_work_orders_path(scope: 'pending'), class: "button"
          end
        end

        panel "待处理沟通工单" do
          table_for CommunicationWorkOrder.pending.includes(:reimbursement).order(created_at: :desc).limit(10) do
            column("ID") { |wo| link_to(wo.id, admin_communication_work_order_path(wo)) }
            column("报销单") { |wo| link_to(wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement)) }
            column("问题类型") { |wo| wo.problem_type&.display_name }
            column("创建时间") { |wo| wo.created_at.strftime("%Y-%m-%d %H:%M") }
          end
          div class: 'panel-footer' do
            link_to "查看全部", admin_communication_work_orders_path(scope: 'pending'), class: "button"
          end
        end

        # panel "需要沟通的工单" do
        #   table_for CommunicationWorkOrder.needs_communication.includes(:reimbursement).order(created_at: :desc).limit(10) do
        #     column("ID") { |wo| link_to(wo.id, admin_communication_work_order_path(wo)) }
        #     column("报销单") { |wo| link_to(wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement)) }
        #     column("问题类型") { |wo| wo.problem_type }
        #     column("创建时间") { |wo| wo.created_at.strftime("%Y-%m-%d %H:%M") }
        #   end
        #   div class: 'panel-footer' do
        #     link_to "查看全部", admin_communication_work_orders_path(scope: 'needs_communication'), class: "button"
        #   end
        # end
      end
    end

    columns do
      column do
        panel "我的报销单" do
          table_for Reimbursement.joins(:active_assignment)
                              .where(reimbursement_assignments: { assignee_id: current_admin_user.id })
                              .order(created_at: :desc)
                              .limit(10) do
            column :invoice_number do |reimbursement|
              link_to reimbursement.invoice_number, admin_reimbursement_path(reimbursement)
            end
            column :status do |reimbursement|
              status_tag reimbursement.status
            end
            column :created_at
          end
          div do
            link_to "查看所有我的报销单", admin_reimbursements_path(scope: 'my_assignments'), class: "button"
          end
        end
      end
      
      column do
        panel "未分配的报销单" do
          table_for Reimbursement.left_joins(:active_assignment)
                              .where(reimbursement_assignments: { id: nil })
                              .order(created_at: :desc)
                              .limit(10) do
            column :invoice_number do |reimbursement|
              link_to reimbursement.invoice_number, admin_reimbursement_path(reimbursement)
            end
            column :status do |reimbursement|
              status_tag reimbursement.status
            end
            column :created_at
          end
          div do
            link_to "查看所有未分配的报销单", admin_reimbursements_path(scope: 'unassigned'), class: "button"
          end
        end
      end
    end
    


    # 移除了快速操作和最近验证的费用明细区块
  end
end
