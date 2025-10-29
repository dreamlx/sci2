# app/admin/operation_statistics.rb
ActiveAdmin.register_page 'Operation Statistics' do
  menu label: '操作统计', priority: 10

  content title: '操作统计' do
    # 按操作类型统计
    panel '按操作类型统计' do
      operation_counts = WorkOrderOperation.group(:operation_type).count
      if operation_counts.any?
        h4 "操作类型分布:"
        ul do
          operation_counts.each do |operation_type, count|
            li "#{WorkOrderOperation.new(operation_type: operation_type).operation_type_display}: #{count}"
          end
        end
      else
        para "暂无操作记录"
      end
    end

    # 按操作人统计
    panel '按操作人统计' do
      user_counts = WorkOrderOperation.joins(:admin_user).group('admin_users.email').count
      if user_counts.any?
        h4 "操作人分布:"
        ul do
          user_counts.each do |email, count|
            li "#{email}: #{count}"
          end
        end
      else
        para "暂无操作记录"
      end
    end

    # 最近30天操作趋势
    panel '最近30天操作趋势' do
      operations_by_day = WorkOrderOperation.where('created_at >= ?', 30.days.ago)
                                             .group("DATE(created_at)")
                                             .count

      if operations_by_day.any?
        h4 "每日操作数量:"
        operations_by_day.sort.each do |date, count|
          span "#{date}: #{count} "
        end
      else
        para '最近30天没有操作记录'
      end
    end

    # 操作排行榜
    panel '操作排行榜' do
      top_users = AdminUser.joins(:work_order_operations)
                          .select('admin_users.*, COUNT(work_order_operations.id) as operations_count')
                          .group('admin_users.id')
                          .order('operations_count DESC')
                          .limit(10)

      if top_users.any?
        h4 "操作数量前10名:"
        ol do
          top_users.each do |user|
            li "#{user.email}: #{user.operations_count}"
          end
        end
      else
        para "暂无操作记录"
      end
    end

    # 总体统计
    panel '总体统计' do
      attributes_table_for WorkOrderOperation.new do
        row('总操作数') { WorkOrderOperation.count }
        row('今日操作数') { WorkOrderOperation.where('created_at >= ?', Date.today).count }
        row('本周操作数') { WorkOrderOperation.where('created_at >= ?', 1.week.ago).count }
        row('本月操作数') { WorkOrderOperation.where('created_at >= ?', 1.month.ago).count }
      end
    end
  end
end
