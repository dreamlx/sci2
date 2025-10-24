namespace :data do
  desc '清空 FeeType 和 ProblemType 表，绕过所有回调和外键约束'
  task clear_fee_and_problem_types: :environment do
    puts '开始清空 FeeType 和 ProblemType 表...'

    # 禁用外键约束（SQLite 特定）
    if ActiveRecord::Base.connection.adapter_name == 'SQLite'
      ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = OFF')
    end

    begin
      # 直接删除数据，绕过回调
      puts '删除 WorkOrderProblem 记录...'
      ActiveRecord::Base.connection.execute('DELETE FROM work_order_problems')

      puts '清空 WorkOrder 表中的 problem_type_id...'
      ActiveRecord::Base.connection.execute('UPDATE work_orders SET problem_type_id = NULL WHERE problem_type_id IS NOT NULL')

      puts '删除 ProblemType 记录...'
      ActiveRecord::Base.connection.execute('DELETE FROM problem_types')

      puts '删除 FeeType 记录...'
      ActiveRecord::Base.connection.execute('DELETE FROM fee_types')

      puts '清空操作完成！'
    rescue StandardError => e
      puts "清空操作失败: #{e.message}"
      raise e
    ensure
      # 重新启用外键约束
      if ActiveRecord::Base.connection.adapter_name == 'SQLite'
        ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = ON')
      end
    end
  end
end
