namespace :sqlite do
  desc "Test SQLite optimization performance"
  task :test_optimization => :environment do
    puts "🚀 SQLite优化性能测试开始..."
    puts "=" * 60
    
    # 检查数据库类型
    unless ActiveRecord::Base.connection.adapter_name.downcase.include?('sqlite')
      puts "❌ 当前数据库不是SQLite，跳过测试"
      exit
    end
    
    # 测试不同优化级别
    levels = [:safe, :moderate, :aggressive]
    test_results = {}
    
    levels.each do |level|
      puts "\n📊 测试优化级别: #{level.upcase}"
      puts "-" * 40
      
      begin
        manager = SqliteOptimizationManager.new(level: level)
        
        # 显示数据库信息
        db_info = manager.database_info
        puts "数据库适配器: #{db_info[:adapter]}"
        puts "数据库路径: #{db_info[:database_path]}"
        puts "优化级别: #{db_info[:optimization_level]}"
        
        # 测试PRAGMA设置应用
        start_time = Time.current
        manager.during_import do
          # 模拟一些数据库操作
          perform_test_operations
        end
        elapsed_time = Time.current - start_time
        
        test_results[level] = {
          elapsed_time: elapsed_time.round(3),
          success: true
        }
        
        puts "✅ 测试完成，耗时: #{elapsed_time.round(3)}秒"
        
      rescue => e
        puts "❌ 测试失败: #{e.message}"
        test_results[level] = {
          elapsed_time: nil,
          success: false,
          error: e.message
        }
      end
    end
    
    # 显示测试结果汇总
    puts "\n" + "=" * 60
    puts "📈 测试结果汇总"
    puts "=" * 60
    
    test_results.each do |level, result|
      status = result[:success] ? "✅ 成功" : "❌ 失败"
      time_info = result[:elapsed_time] ? "#{result[:elapsed_time]}秒" : "N/A"
      puts "#{level.to_s.upcase.ljust(10)} | #{status} | 耗时: #{time_info}"
      puts "错误: #{result[:error]}" if result[:error]
    end
    
    # 性能对比
    if test_results.values.all? { |r| r[:success] }
      puts "\n📊 性能对比 (相对于SAFE级别):"
      safe_time = test_results[:safe][:elapsed_time]
      test_results.each do |level, result|
        next if level == :safe
        improvement = ((safe_time - result[:elapsed_time]) / safe_time * 100).round(1)
        puts "#{level.to_s.upcase}: #{improvement > 0 ? '+' : ''}#{improvement}% 性能变化"
      end
    end
    
    puts "\n🎉 SQLite优化测试完成!"
  end
  
  desc "Show current SQLite settings"
  task :show_settings => :environment do
    unless ActiveRecord::Base.connection.adapter_name.downcase.include?('sqlite')
      puts "❌ 当前数据库不是SQLite"
      exit
    end
    
    puts "📋 当前SQLite设置:"
    puts "=" * 40
    
    settings = %w[synchronous journal_mode cache_size page_size temp_store foreign_keys]
    connection = ActiveRecord::Base.connection
    
    settings.each do |setting|
      begin
        value = connection.select_value("PRAGMA #{setting}")
        puts "#{setting.ljust(15)}: #{value}"
      rescue => e
        puts "#{setting.ljust(15)}: Error - #{e.message}"
      end
    end
  end
  
  desc "Run import performance benchmark"
  task :benchmark_import => :environment do
    puts "🏃‍♂️ 导入性能基准测试"
    puts "=" * 50
    
    # 创建测试数据
    test_data = create_test_import_data
    
    levels = [:safe, :moderate]
    results = {}
    
    levels.each do |level|
      puts "\n测试级别: #{level.upcase}"
      puts "-" * 30
      
      # 清理之前的测试数据
      cleanup_test_data
      
      manager = SqliteOptimizationManager.new(level: level)
      
      start_time = Time.current
      manager.during_import_with_monitoring do
        # 模拟批量插入
        import_test_data(test_data)
      end
      elapsed_time = Time.current - start_time
      
      record_count = test_data.size
      rps = (record_count / elapsed_time).round(2)
      
      results[level] = {
        elapsed_time: elapsed_time.round(3),
        record_count: record_count,
        records_per_second: rps
      }
      
      puts "记录数: #{record_count}"
      puts "耗时: #{elapsed_time.round(3)}秒"
      puts "速度: #{rps} 记录/秒"
    end
    
    # 性能对比
    puts "\n📊 性能对比:"
    puts "=" * 30
    safe_rps = results[:safe][:records_per_second]
    results.each do |level, result|
      improvement = level == :safe ? 0 : ((result[:records_per_second] - safe_rps) / safe_rps * 100).round(1)
      puts "#{level.to_s.upcase}: #{result[:records_per_second]} 记录/秒 (#{improvement > 0 ? '+' : ''}#{improvement}%)"
    end
  end
  
  private
  
  def perform_test_operations
    # 模拟一些数据库操作
    connection = ActiveRecord::Base.connection
    
    # 创建临时表
    connection.execute("CREATE TEMP TABLE test_table (id INTEGER, name TEXT, value REAL)")
    
    # 插入测试数据
    100.times do |i|
      connection.execute("INSERT INTO test_table VALUES (#{i}, 'test_#{i}', #{rand * 100})")
    end
    
    # 查询操作
    connection.select_all("SELECT COUNT(*) FROM test_table")
    connection.select_all("SELECT * FROM test_table WHERE id < 50")
    
    # 删除临时表
    connection.execute("DROP TABLE test_table")
  end
  
  def create_test_import_data
    # 创建1000条测试报销单数据
    (1..1000).map do |i|
      {
        invoice_number: "TEST#{i.to_s.rjust(6, '0')}",
        document_name: "测试报销单#{i}",
        applicant: "测试用户#{i}",
        applicant_id: "EMP#{i.to_s.rjust(4, '0')}",
        company: "测试公司",
        department: "测试部门",
        amount: rand(1000..10000),
        external_status: "已提交"
      }
    end
  end
  
  def import_test_data(test_data)
    # 批量插入测试数据
    test_data.each do |data|
      Reimbursement.create!(data)
    end
  end
  
  def cleanup_test_data
    # 简化清理，使用destroy_all来处理外键约束
    Reimbursement.where("invoice_number LIKE 'TEST%'").destroy_all
  rescue => e
    Rails.logger.warn "清理测试数据时出现错误: #{e.message}"
    # 如果destroy_all失败，尝试直接删除
    ActiveRecord::Base.connection.execute("DELETE FROM reimbursements WHERE invoice_number LIKE 'TEST%'")
  end
end