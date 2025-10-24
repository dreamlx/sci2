ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do
    columns do
      column do
        panel '系统概览' do
          div class: 'dashboard-stats' do
            div class: 'stat-box' do
              h4 '今日导入报销单'
              h3 Reimbursement.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
            end

            div class: 'stat-box' do
              h4 '今日导入快递收单'
              h3 WorkOrder.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
            end

            div class: 'stat-box' do
              h4 '今日导入费用明细'
              h3 FeeDetail.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
            end

            div class: 'stat-box' do
              h4 '今日导入操作历史记录'
              h3 OperationHistory.where(created_at: Date.current.beginning_of_day..Date.current.end_of_day).count
            end
          end
        end

        panel '系统操作' do
          div class: 'dashboard-stats' do
            div class: 'stat-box' do
              p '导入报销单'
              a href: new_import_admin_reimbursements_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入报销单'
              end
            end

            div class: 'stat-box' do
              p '导入费用明细'
              a href: new_import_admin_fee_details_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入费用明细'
              end
            end

            div class: 'stat-box' do
              p '导入快递收单'
              a href: new_import_admin_express_receipt_work_orders_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入快递收单'
              end
            end

            div class: 'stat-box' do
              p '导入操作历史'
              a href: operation_histories_admin_imports_path, class: 'import-button' do
                i class: 'fa fa-file-import fa-3x', 'data-label': '导入操作历史'
              end
            end

            div class: 'stat-box' do
              p '分配报销单'
              a href: admin_reimbursements_path(scope: 'unassigned'), class: 'import-button' do
                i class: 'fa fa-user-plus fa-3x', 'data-label': '分配报销单'
              end
            end

            div class: 'stat-box' do
              p '查看分配给我的报销单'
              a href: '/admin/reimbursements?scope=my_assignments', class: 'import-button' do
                i class: 'fa fa-tasks fa-3x', 'data-label': '查看分配给我的报销单'
              end
            end
          end
        end
      end
    end

    columns do
      column do
        panel '今日分配给我的报销单' do
          table_for Reimbursement.joins(:active_assignment)
                                 .where(reimbursement_assignments: { assignee_id: current_admin_user.id })
                                 .where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
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
            link_to '查看所有我的报销单', admin_reimbursements_path(scope: 'my_assignments'), class: 'button'
          end
        end
      end

      column do
        panel '今日未分配的报销单' do
          table_for Reimbursement.unassigned
                                 .where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
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
            link_to '查看所有未分配的报销单', admin_reimbursements_path(scope: 'unassigned'), class: 'button'
            span style: 'margin: 0 5px;'
            link_to '查看当天未分配的报销单',
                    admin_reimbursements_path(scope: 'unassigned', q: { created_at_gteq: Date.current.beginning_of_day, created_at_lteq: Date.current.end_of_day }), class: 'button'
          end
        end
      end
    end

    # 移除了快速操作和最近验证的费用明细区块
  end
end
