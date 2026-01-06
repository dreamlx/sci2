# app/services/workload_statistics_service.rb
# 工作量统计服务
# 提供按审核员、时间段统计真实工作量的功能
class WorkloadStatisticsService
  # 时间段常量
  PERIOD_TODAY = 'today'.freeze
  PERIOD_WEEK = 'week'.freeze
  PERIOD_MONTH = 'month'.freeze

  # 复杂度权重（可配置）
  WEIGHTS = {
    audit_work_order: 1.0,        # 审核工单基础分
    communication_work_order: 0.8, # 沟通工单基础分
    fee_detail: 0.2,              # 每个费用明细
    problem_type: 0.3             # 每个问题类型
  }.freeze

  def initialize(period: PERIOD_TODAY, start_date: nil, end_date: nil)
    @period = period
    @start_date = start_date
    @end_date = end_date
    calculate_date_range
  end

  # 获取所有审核员的工作量统计
  def all_auditors_workload
    auditors = AdminUser.joins(:created_work_orders)
                        .where(work_orders: { created_at: @date_range })
                        .distinct

    auditors.map do |auditor|
      auditor_workload(auditor)
    end.sort_by { |w| -w[:weighted_score] }
  end

  # 获取单个审核员的工作量统计
  def auditor_workload(auditor)
    audit_orders = AuditWorkOrder.where(created_by: auditor.id, created_at: @date_range)
    communication_orders = CommunicationWorkOrder.where(created_by: auditor.id, created_at: @date_range)

    audit_count = audit_orders.count
    communication_count = communication_orders.count

    # 处理的费用明细数（通过工单关联）
    all_work_orders = WorkOrder.where(created_by: auditor.id, created_at: @date_range)
    fee_detail_count = WorkOrderFeeDetail.where(work_order_id: all_work_orders.select(:id)).count

    # 发现的问题数
    problem_count = WorkOrderProblem.where(work_order_id: all_work_orders.select(:id)).count

    # 处理的报销单数（去重）
    reimbursement_count = all_work_orders.distinct.count(:reimbursement_id)

    # 计算加权工作量分
    weighted_score = calculate_weighted_score(
      audit_count: audit_count,
      communication_count: communication_count,
      fee_detail_count: fee_detail_count,
      problem_count: problem_count
    )

    {
      auditor_id: auditor.id,
      auditor_name: auditor.name || auditor.email,
      auditor_email: auditor.email,
      audit_work_orders: audit_count,
      communication_work_orders: communication_count,
      total_work_orders: audit_count + communication_count,
      fee_details_processed: fee_detail_count,
      problems_found: problem_count,
      reimbursements_processed: reimbursement_count,
      weighted_score: weighted_score.round(1),
      period: @period,
      date_range: { start: @date_range.first, end: @date_range.last }
    }
  end

  # 获取工作量趋势（按日统计）
  def daily_trend(days: 30)
    end_date = Date.current
    start_date = end_date - days.days

    (start_date..end_date).map do |date|
      date_range = date.beginning_of_day..date.end_of_day
      {
        date: date,
        audit_work_orders: AuditWorkOrder.where(created_at: date_range).count,
        communication_work_orders: CommunicationWorkOrder.where(created_at: date_range).count,
        fee_details_processed: fee_details_count_for_range(date_range),
        problems_found: problems_count_for_range(date_range)
      }
    end
  end

  # 获取工作量排行榜
  def leaderboard(limit: 10)
    all_auditors_workload.first(limit)
  end

  # 获取总体统计
  def summary
    audit_count = AuditWorkOrder.where(created_at: @date_range).count
    communication_count = CommunicationWorkOrder.where(created_at: @date_range).count
    fee_detail_count = fee_details_count_for_range(@date_range)
    problem_count = problems_count_for_range(@date_range)
    reimbursement_count = WorkOrder.where(created_at: @date_range).distinct.count(:reimbursement_id)
    active_auditors = AdminUser.joins(:created_work_orders)
                               .where(work_orders: { created_at: @date_range })
                               .distinct.count

    {
      period: @period,
      date_range: { start: @date_range.first, end: @date_range.last },
      audit_work_orders: audit_count,
      communication_work_orders: communication_count,
      total_work_orders: audit_count + communication_count,
      fee_details_processed: fee_detail_count,
      problems_found: problem_count,
      reimbursements_processed: reimbursement_count,
      active_auditors: active_auditors,
      avg_work_orders_per_auditor: active_auditors > 0 ? ((audit_count + communication_count) / active_auditors.to_f).round(1) : 0
    }
  end

  # 按费用类型统计工作量（分析复杂度分布）
  def workload_by_fee_type
    work_orders = WorkOrder.where(created_at: @date_range)

    FeeDetail.joins(:work_order_fee_details)
             .where(work_order_fee_details: { work_order_id: work_orders.select(:id) })
             .group(:fee_type)
             .count
             .sort_by { |_k, v| -v }
             .to_h
  end

  private

  def calculate_date_range
    @date_range = case @period
                  when PERIOD_TODAY
                    Date.current.beginning_of_day..Date.current.end_of_day
                  when PERIOD_WEEK
                    1.week.ago.beginning_of_day..Date.current.end_of_day
                  when PERIOD_MONTH
                    1.month.ago.beginning_of_day..Date.current.end_of_day
                  else
                    if @start_date && @end_date
                      @start_date.beginning_of_day..@end_date.end_of_day
                    else
                      Date.current.beginning_of_day..Date.current.end_of_day
                    end
                  end
  end

  def calculate_weighted_score(audit_count:, communication_count:, fee_detail_count:, problem_count:)
    (audit_count * WEIGHTS[:audit_work_order]) +
      (communication_count * WEIGHTS[:communication_work_order]) +
      (fee_detail_count * WEIGHTS[:fee_detail]) +
      (problem_count * WEIGHTS[:problem_type])
  end

  def fee_details_count_for_range(date_range)
    work_orders = WorkOrder.where(created_at: date_range)
    WorkOrderFeeDetail.where(work_order_id: work_orders.select(:id)).count
  end

  def problems_count_for_range(date_range)
    work_orders = WorkOrder.where(created_at: date_range)
    WorkOrderProblem.where(work_order_id: work_orders.select(:id)).count
  end
end
