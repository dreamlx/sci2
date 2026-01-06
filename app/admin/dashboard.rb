ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: proc { I18n.t('active_admin.dashboard') }

  content title: proc { I18n.t('active_admin.dashboard') } do
    today_range = Date.current.beginning_of_day..Date.current.end_of_day

    columns do
      column do
        panel '今日数据导入' do
          div class: 'dashboard-stats' do
            div class: 'stat-box' do
              h4 '导入报销单'
              h3 Reimbursement.where(created_at: today_range).count
            end

            div class: 'stat-box' do
              h4 '导入费用明细'
              h3 FeeDetail.where(created_at: today_range).count
            end

            div class: 'stat-box' do
              h4 '导入快递收单'
              h3 ExpressReceiptWorkOrder.where(created_at: today_range).count
            end

            div class: 'stat-box' do
              h4 '导入操作历史'
              h3 OperationHistory.where(created_at: today_range).count
            end
          end
        end

        panel '今日工作产出' do
          div class: 'dashboard-stats' do
            div class: 'stat-box highlight' do
              h4 '创建审核工单'
              h3 AuditWorkOrder.where(created_at: today_range).count
            end

            div class: 'stat-box highlight' do
              h4 '创建沟通工单'
              h3 CommunicationWorkOrder.where(created_at: today_range).count
            end

            div class: 'stat-box' do
              h4 '处理费用明细'
              work_order_ids = WorkOrder.where(created_at: today_range).select(:id)
              h3 WorkOrderFeeDetail.where(work_order_id: work_order_ids).count
            end

            div class: 'stat-box' do
              h4 '发现问题'
              h3 WorkOrderProblem.where(created_at: today_range).count
            end
          end
        end

        panel '快捷操作' do
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
              p '分配报销单'
              a href: admin_reimbursements_path(scope: 'unassigned'), class: 'import-button' do
                i class: 'fa fa-user-plus fa-3x', 'data-label': '分配报销单'
              end
            end

            div class: 'stat-box' do
              p '工作量统计'
              a href: admin_workload_statistics_path, class: 'import-button' do
                i class: 'fa fa-chart-bar fa-3x', 'data-label': '工作量统计'
              end
            end
          end
        end
      end
    end

    columns do
      column do
        panel '我的待处理报销单' do
          my_reimbursements = Reimbursement.joins(:active_assignment)
                                           .where(reimbursement_assignments: { assignee_id: current_admin_user.id })
                                           .where(status: [Reimbursement::STATUS_PENDING, Reimbursement::STATUS_PROCESSING])
                                           .order(created_at: :desc)
                                           .limit(10)

          if my_reimbursements.any?
            table_for my_reimbursements do
              column :invoice_number do |reimbursement|
                link_to reimbursement.invoice_number, admin_reimbursement_path(reimbursement)
              end
              column :status do |reimbursement|
                status_tag reimbursement.status
              end
              column '费用明细数' do |reimbursement|
                reimbursement.fee_details.count
              end
              column :created_at
            end
          else
            para '暂无待处理的报销单'
          end

          div do
            link_to '查看所有我的报销单', admin_reimbursements_path(scope: 'my_assignments'), class: 'button'
          end
        end
      end

      column do
        panel '未分配的报销单' do
          unassigned = Reimbursement.unassigned
                                    .where(status: [Reimbursement::STATUS_PENDING, Reimbursement::STATUS_PROCESSING])
                                    .order(created_at: :desc)
                                    .limit(10)

          if unassigned.any?
            table_for unassigned do
              column :invoice_number do |reimbursement|
                link_to reimbursement.invoice_number, admin_reimbursement_path(reimbursement)
              end
              column :status do |reimbursement|
                status_tag reimbursement.status
              end
              column '费用明细数' do |reimbursement|
                reimbursement.fee_details.count
              end
              column :created_at
            end
          else
            para '暂无未分配的报销单'
          end

          div do
            total_unassigned = Reimbursement.unassigned
                                            .where(status: [Reimbursement::STATUS_PENDING, Reimbursement::STATUS_PROCESSING])
                                            .count
            link_to "查看所有未分配 (#{total_unassigned})", admin_reimbursements_path(scope: 'unassigned'), class: 'button'
          end
        end
      end
    end

    # 样式
    div do
      style do
        text_node <<~CSS
          .stat-box.highlight {
            background: #e8f5e9 !important;
            border-color: #4caf50 !important;
          }
          .stat-box.highlight h3 {
            color: #2e7d32 !important;
          }
        CSS
      end
    end
  end
end
