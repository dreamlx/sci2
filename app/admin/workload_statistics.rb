# app/admin/workload_statistics.rb
# 工作量统计页面 - 按审核员统计真实工作产出
ActiveAdmin.register_page 'Workload Statistics' do
  menu label: '工作量统计', priority: 9

  content title: '工作量统计' do
    # 时间段选择
    period = params[:period] || 'today'
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil

    service = WorkloadStatisticsService.new(
      period: period,
      start_date: start_date,
      end_date: end_date
    )

    # 时间段筛选器
    panel '筛选条件' do
      form action: admin_workload_statistics_path, method: :get do |f|
        f.input :hidden, name: :locale, value: I18n.locale
        div class: 'filter-form' do
          span '时间段: '
          select name: :period do
            option '今日', value: 'today', selected: period == 'today'
            option '本周', value: 'week', selected: period == 'week'
            option '本月', value: 'month', selected: period == 'month'
            option '自定义', value: 'custom', selected: period == 'custom'
          end
          span ' 或自定义: '
          input type: :date, name: :start_date, value: start_date
          span ' 至 '
          input type: :date, name: :end_date, value: end_date
          input type: :submit, value: '查询'
        end
      end
    end

    # 总体统计
    summary = service.summary
    panel '总体统计' do
      columns do
        column do
          div class: 'stat-box summary-stat' do
            h4 '审核工单'
            h2 summary[:audit_work_orders]
          end
        end
        column do
          div class: 'stat-box summary-stat' do
            h4 '沟通工单'
            h2 summary[:communication_work_orders]
          end
        end
        column do
          div class: 'stat-box summary-stat' do
            h4 '处理费用明细'
            h2 summary[:fee_details_processed]
          end
        end
        column do
          div class: 'stat-box summary-stat' do
            h4 '发现问题'
            h2 summary[:problems_found]
          end
        end
        column do
          div class: 'stat-box summary-stat' do
            h4 '处理报销单'
            h2 summary[:reimbursements_processed]
          end
        end
        column do
          div class: 'stat-box summary-stat' do
            h4 '活跃审核员'
            h2 summary[:active_auditors]
          end
        end
      end
    end

    # 审核员工作量排行
    panel '审核员工作量排行' do
      workloads = service.all_auditors_workload

      if workloads.any?
        table_for workloads do
          column '排名' do |w|
            workloads.index(w) + 1
          end
          column '审核员' do |w|
            w[:auditor_name]
          end
          column '审核工单' do |w|
            w[:audit_work_orders]
          end
          column '沟通工单' do |w|
            w[:communication_work_orders]
          end
          column '工单总数' do |w|
            w[:total_work_orders]
          end
          column '费用明细' do |w|
            w[:fee_details_processed]
          end
          column '发现问题' do |w|
            w[:problems_found]
          end
          column '报销单数' do |w|
            w[:reimbursements_processed]
          end
          column '加权工作量' do |w|
            status_tag w[:weighted_score], class: w[:weighted_score] > 10 ? 'ok' : 'warning'
          end
        end
      else
        para '该时间段内没有工作记录'
      end
    end

    # 按费用类型统计
    panel '按费用类型统计（工作复杂度分布）' do
      fee_type_stats = service.workload_by_fee_type

      if fee_type_stats.any?
        table_for fee_type_stats.to_a do
          column '费用类型' do |item|
            item[0]
          end
          column '处理数量' do |item|
            item[1]
          end
          column '占比' do |item|
            total = fee_type_stats.values.sum
            percentage = (item[1].to_f / total * 100).round(1)
            "#{percentage}%"
          end
        end
      else
        para '该时间段内没有费用明细处理记录'
      end
    end

    # 最近30天趋势（仅在非自定义模式下显示）
    if period != 'custom'
      panel '最近30天工作量趋势' do
        trend_data = service.daily_trend(days: 30)

        div class: 'trend-summary' do
          h4 '每日工单数量:'
          trend_data.each do |day|
            total = day[:audit_work_orders] + day[:communication_work_orders]
            if total > 0
              span class: 'trend-item' do
                text_node "#{day[:date].strftime('%m/%d')}: "
                strong total.to_s
                text_node ' '
              end
            end
          end
        end
      end
    end

    # 样式
    div do
      style do
        text_node <<~CSS
          .filter-form {
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
          }
          .filter-form select, .filter-form input[type="date"] {
            padding: 5px 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
          }
          .filter-form input[type="submit"] {
            background: #5c90d2;
            color: white;
            border: none;
            padding: 6px 15px;
            border-radius: 4px;
            cursor: pointer;
          }
          .stat-box.summary-stat {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
            border: 1px solid #e9ecef;
          }
          .stat-box.summary-stat h4 {
            margin: 0 0 10px 0;
            color: #6c757d;
            font-size: 14px;
          }
          .stat-box.summary-stat h2 {
            margin: 0;
            color: #495057;
            font-size: 28px;
          }
          .trend-summary {
            line-height: 2;
          }
          .trend-item {
            display: inline-block;
            margin-right: 15px;
            background: #f0f0f0;
            padding: 2px 8px;
            border-radius: 4px;
          }
        CSS
      end
    end
  end
end
