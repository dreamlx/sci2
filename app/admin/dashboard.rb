ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "系统概览" do
          div class: 'dashboard-stats' do
            div class: 'stat-box' do
              h3 Reimbursement.count
              p "报销单总数"
            end

            div class: 'stat-box' do
              h3 WorkOrder.count
              p "工单总数"
            end

            div class: 'stat-box' do
              h3 FeeDetail.count
              p "费用明细总数"
            end

            div class: 'stat-box' do
              h3 FeeDetail.where(verification_status: 'verified').count
              p "已验证费用明细"
            end
          end
        end

        panel "报销单状态分布" do
          div class: 'dashboard-chart', id: 'reimbursement-status-chart' do
            # 图表将通过JavaScript渲染
          end

          div class: 'chart-legend' do
            ul do
              li do
                span class: 'legend-color pending'
                text_node "待处理"
              end
              li do
                span class: 'legend-color processing'
                text_node "处理中"
              end
              li do
                span class: 'legend-color waiting_completion'
                text_node "等待完成"
              end
              li do
                span class: 'legend-color closed'
                text_node "已关闭"
              end
            end
          end

          script do
            raw "
              document.addEventListener('DOMContentLoaded', function() {
                const ctx = document.getElementById('reimbursement-status-chart').getContext('2d');

                fetch('/admin/statistics/reimbursement_status_counts')
                  .then(response => response.json())
                  .then(data => {
                    new Chart(ctx, {
                      type: 'doughnut',
                      data: {
                        labels: ['待处理', '处理中', '等待完成', '已关闭'],
                        datasets: [{
                          data: [data.pending, data.processing, data.waiting_completion, data.closed],
                          backgroundColor: ['#6c757d', '#007bff', '#fd7e14', '#28a745']
                        }]
                      },
                      options: {
                        responsive: true,
                        maintainAspectRatio: false
                      }
                    });
                  });
              });
            "
          end
        end
      end

      column do
        panel "待处理审核工单" do
          table_for AuditWorkOrder.pending.includes(:reimbursement).order(created_at: :desc).limit(10) do
            column("ID") { |wo| link_to(wo.id, admin_audit_work_order_path(wo)) }
            column("报销单") { |wo| link_to(wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement)) }
            column("问题类型") { |wo| wo.problem_type }
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
            column("问题类型") { |wo| wo.problem_type }
            column("创建时间") { |wo| wo.created_at.strftime("%Y-%m-%d %H:%M") }
          end
          div class: 'panel-footer' do
            link_to "查看全部", admin_communication_work_orders_path(scope: 'pending'), class: "button"
          end
        end

        panel "需要沟通的工单" do
          table_for CommunicationWorkOrder.needs_communication.includes(:reimbursement).order(created_at: :desc).limit(10) do
            column("ID") { |wo| link_to(wo.id, admin_communication_work_order_path(wo)) }
            column("报销单") { |wo| link_to(wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement)) }
            column("问题类型") { |wo| wo.problem_type }
            column("创建时间") { |wo| wo.created_at.strftime("%Y-%m-%d %H:%M") }
          end
          div class: 'panel-footer' do
            link_to "查看全部", admin_communication_work_orders_path(scope: 'needs_communication'), class: "button"
          end
        end
      end
    end

    columns do
      column do
        panel "快速操作" do
          div class: 'quick-actions' do
            div class: 'action-button' do
              link_to admin_reimbursements_path do
                i class: 'fa fa-file-invoice'
                span "报销单管理"
              end
            end

            div class: 'action-button' do
              link_to new_admin_audit_work_order_path do
                i class: 'fa fa-clipboard-check'
                span "新建审核工单"
              end
            end

            div class: 'action-button' do
              link_to new_admin_communication_work_order_path do
                i class: 'fa fa-comments'
                span "新建沟通工单"
              end
            end

            div class: 'action-button' do
              link_to new_import_admin_reimbursements_path do
                i class: 'fa fa-file-import'
                span "导入报销单"
              end
            end

            div class: 'action-button' do
              link_to new_import_admin_fee_details_path do
                i class: 'fa fa-file-import'
                span "导入费用明细"
              end
            end

            div class: 'action-button' do
              link_to new_import_admin_express_receipt_work_orders_path do
                i class: 'fa fa-file-import'
                span "导入快递收单"
              end
            end
          end
        end
      end

      column do
        panel "最近验证的费用明细" do
          table_for FeeDetail.where(verification_status: 'verified').order(updated_at: :desc).limit(10) do
            column("ID") { |fd| link_to(fd.id, admin_fee_detail_path(fd)) }
            column("报销单") { |fd| link_to(fd.document_number, admin_reimbursement_path(fd.reimbursement)) if fd.reimbursement }
            column("费用类型") { |fd| fd.fee_type }
            column("金额") { |fd| number_to_currency(fd.amount, unit: "¥") }
            column("验证时间") { |fd| fd.updated_at.strftime("%Y-%m-%d %H:%M") }
          end
        end
      end
    end
  end
end
