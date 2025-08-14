# Rails项目SQLite导入优化方案

## 1. 优化背景

基于SQLite性能优化案例（从每秒85条提升到96,000条），结合我们Rails项目的实际情况，设计一套完整的导入优化方案。我们的目标是显著提升Excel文件导入到SQLite数据库的性能。

## 2. 核心优化策略

### 2.1 事务优化（Transaction）

**原理**：将所有插入操作放在一个事务中，避免每次插入都创建新事务的开销。

**Rails实现**：
```ruby
# 原始代码（每次插入都在独立事务中）
def import_without_transaction
  rows.each do |row|
    FeeDetail.create!(row.to_h)
  end
end

# 优化后代码（单个事务）
def import_with_transaction
  FeeDetail.transaction do
    rows.each do |row|
      FeeDetail.create!(row.to_h)
    end
  end
end
```

**预期性能提升**：约270倍（从85条/秒到23,000条/秒）

### 2.2 预处理语句优化（Prepared Statements）

**原理**：使用预处理语句避免SQL解析开销，类似案例中的`sqlite3_prepare_v2`。

**Rails实现**：
```ruby
# 使用Active Record的批量插入
def import_with_bulk_insert
  fee_details = rows.map do |row|
    {
      reimbursement_id: row[0],
      fee_type: row[1],
      amount: row[2],
      # 其他字段...
    }
  end
  
  FeeDetail.insert_all(fee_details) # 单条SQL批量插入
end

# 或者使用原始SQL预处理
def import_with_prepared_statements
  sql = "INSERT INTO fee_details (reimbursement_id, fee_type, amount, ...) VALUES (?, ?, ?, ...)"
  
  FeeDetail.connection.transaction do
    stmt = FeeDetail.connection.raw_connection.prepare(sql)
    
    rows.each do |row|
      stmt.execute(row[0], row[1], row[2], ...)
    end
    
    stmt.close
  end
end
```

**预期性能提升**：约2.3倍（从23,000条/秒到53,000条/秒）

### 2.3 SQLite配置优化

**原理**：调整SQLite的PRAGMA设置，减少磁盘I/O和同步等待。

**Rails实现**：
```ruby
# 在导入前设置SQLite优化参数
def optimize_sqlite_settings
  connection = FeeDetail.connection
  
  # 关闭同步等待，提升写入速度
  connection.execute("PRAGMA synchronous = OFF")
  
  # 使用内存日志，减少磁盘I/O
  connection.execute("PRAGMA journal_mode = MEMORY")
  
  # 增加页面大小，提升读写效率
  connection.execute("PRAGMA page_size = 4096")
  
  # 增加缓存大小
  connection.execute("PRAGMA cache_size = 10000")
  
  # 临时关闭外键约束
  connection.execute("PRAGMA foreign_keys = OFF")
end

# 导入完成后恢复默认设置
def restore_sqlite_settings
  connection = FeeDetail.connection
  
  connection.execute("PRAGMA synchronous = NORMAL")
  connection.execute("PRAGMA journal_mode = DELETE")
  connection.execute("PRAGMA foreign_keys = ON")
end

# 完整导入流程
def optimized_import
  optimize_sqlite_settings
  
  begin
    FeeDetail.transaction do
      # 批量插入代码
      import_with_bulk_insert
    end
  ensure
    restore_sqlite_settings
  end
end
```

**预期性能提升**：约1.36倍（从53,000条/秒到72,000条/秒）

### 2.4 索引优化策略

**原理**：先导入数据再创建索引，避免每次插入都更新索引。

**Rails实现**：
```ruby
# 导入前删除索引（如果存在）
def remove_indexes
  connection = FeeDetail.connection
  
  # 检查并删除索引
  indexes = connection.indexes(:fee_details)
  indexes.each do |index|
    connection.execute("DROP INDEX #{index.name}")
  end
end

# 导入后重建索引
def rebuild_indexes
  connection = FeeDetail.connection
  
  # 重建必要的索引
  connection.execute("CREATE INDEX index_fee_details_on_reimbursement_id ON fee_details (reimbursement_id)")
  connection.execute("CREATE INDEX index_fee_details_on_fee_type ON fee_details (fee_type)")
  # 其他索引...
end

# 完整导入流程
def optimized_import_with_indexes
  remove_indexes
  optimize_sqlite_settings
  
  begin
    FeeDetail.transaction do
      import_with_bulk_insert
    end
    
    rebuild_indexes
  ensure
    restore_sqlite_settings
  end
end
```

**预期性能提升**：约1.33倍（从72,000条/秒到96,000条/秒）

### 2.5 Excel文件读取优化

**原理**：优化Roo库的使用方式，减少内存占用和解析时间。

**Rails实现**：
```ruby
# 原始代码（可能存在内存问题）
def read_excel_original
  spreadsheet = Roo::Excelx.new(file_path)
  spreadsheet.each_row_streaming(offset: 1) do |row|
    # 处理每一行
  end
end

# 优化后代码（流式读取，批量处理）
def read_excel_optimized
  spreadsheet = Roo::Excelx.new(file_path)
  batch_size = 1000
  batch = []
  
  spreadsheet.each_row_streaming(offset: 1) do |row|
    batch << process_row(row)
    
    if batch.size >= batch_size
      yield batch
      batch = []
    end
  end
  
  yield batch unless batch.empty?
end

# 使用优化后的读取方法
def import_with_optimized_reading
  optimize_sqlite_settings
  remove_indexes
  
  begin
    FeeDetail.transaction do
      read_excel_optimized do |batch|
        FeeDetail.insert_all(batch)
      end
    end
    
    rebuild_indexes
  ensure
    restore_sqlite_settings
  end
end
```

### 2.6 内存数据库策略（可选）

**原理**：对于临时导入操作，可以使用内存数据库提升性能。

**Rails实现**：
```ruby
# 临时切换到内存数据库
def use_memory_database
  original_config = ActiveRecord::Base.configurations[Rails.env]
  
  # 临时配置内存数据库
  memory_config = original_config.merge('database' => ':memory:')
  ActiveRecord::Base.establish_connection(memory_config)
  
  # 创建表结构
  ActiveRecord::Base.connection.create_table(:fee_details) do |t|
    # 表结构定义...
  end
end

# 导入完成后切换回原数据库
def restore_original_database
  original_config = ActiveRecord::Base.configurations[Rails.env]
  ActiveRecord::Base.establish_connection(original_config)
end
```

## 3. 完整优化方案实现

### 3.1 创建导入服务类

```ruby
# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  BATCH_SIZE = 1000
  
  def initialize(file_path)
    @file_path = file_path
    @connection = FeeDetail.connection
  end
  
  def call
    setup_optimization
    
    begin
      import_data
    ensure
      cleanup_optimization
    end
  end
  
  private
  
  def setup_optimization
    # 保存原始设置
    @original_settings = {
      synchronous: @connection.select_value("PRAGMA synchronous"),
      journal_mode: @connection.select_value("PRAGMA journal_mode"),
      foreign_keys: @connection.select_value("PRAGMA foreign_keys")
    }
    
    # 应用优化设置
    @connection.execute("PRAGMA synchronous = OFF")
    @connection.execute("PRAGMA journal_mode = MEMORY")
    @connection.execute("PRAGMA foreign_keys = OFF")
    @connection.execute("PRAGMA cache_size = 10000")
    
    # 移除索引
    remove_indexes
  end
  
  def cleanup_optimization
    # 恢复原始设置
    @connection.execute("PRAGMA synchronous = #{@original_settings[:synchronous]}")
    @connection.execute("PRAGMA journal_mode = #{@original_settings[:journal_mode]}")
    @connection.execute("PRAGMA foreign_keys = #{@original_settings[:foreign_keys]}")
    
    # 重建索引
    rebuild_indexes
  end
  
  def remove_indexes
    @indexes = @connection.indexes(:fee_details)
    @indexes.each do |index|
      @connection.execute("DROP INDEX #{index.name}")
    end
  end
  
  def rebuild_indexes
    @indexes.each do |index|
      columns = index.columns.join(', ')
      @connection.execute("CREATE INDEX #{index.name} ON fee_details (#{columns})")
    end
  end
  
  def import_data
    spreadsheet = Roo::Excelx.new(@file_path)
    batch = []
    
    FeeDetail.transaction do
      spreadsheet.each_row_streaming(offset: 1) do |row|
        fee_detail = build_fee_detail_from_row(row)
        batch << fee_detail
        
        if batch.size >= BATCH_SIZE
          FeeDetail.insert_all(batch)
          batch = []
        end
      end
      
      # 插入剩余记录
      FeeDetail.insert_all(batch) unless batch.empty?
    end
  end
  
  def build_fee_detail_from_row(row)
    # 根据实际Excel列映射构建FeeDetail对象
    {
      reimbursement_id: row[0],
      fee_type: row[1],
      amount: row[2].to_f,
      # 其他字段...
      created_at: Time.current,
      updated_at: Time.current
    }
  end
end
```

### 3.2 在控制器中使用

```ruby
# app/admin/fee_details.rb
ActiveAdmin.register FeeDetail do
  # ... 其他配置
  
  collection_action :import, method: :post do
    if params[:file].present?
      begin
        # 保存上传的文件
        file_path = Rails.root.join('tmp', "#{SecureRandom.uuid}.xlsx")
        File.binwrite(file_path, params[:file].read)
        
        # 使用优化后的导入服务
        import_service = FeeDetailImportService.new(file_path)
        result = import_service.call
        
        # 删除临时文件
        File.delete(file_path)
        
        redirect_to admin_fee_details_path, notice: "成功导入 #{result} 条记录"
      rescue => e
        redirect_to admin_fee_details_path, alert: "导入失败: #{e.message}"
      end
    else
      redirect_to admin_fee_details_path, alert: "请选择要导入的文件"
    end
  end
  
  # 添加导入表单
  action_item :import do
    link_to '导入Excel', import_admin_fee_details_path, method: :post
  end
end
```

## 4. 性能监控与调优

### 4.1 添加性能监控

```ruby
# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  # ... 其他代码
  
  def call
    @start_time = Time.current
    @record_count = 0
    
    setup_optimization
    
    begin
      import_data
      log_performance
    ensure
      cleanup_optimization
    end
  end
  
  private
  
  def import_data
    # ... 其他代码
    
    spreadsheet.each_row_streaming(offset: 1) do |row|
      fee_detail = build_fee_detail_from_row(row)
      batch << fee_detail
      @record_count += 1
      
      if batch.size >= BATCH_SIZE
        FeeDetail.insert_all(batch)
        batch = []
        log_progress
      end
    end
    
    # ... 其他代码
  end
  
  def log_progress
    elapsed = Time.current - @start_time
    rate = @record_count / elapsed if elapsed > 0
    Rails.logger.info "导入进度: #{@record_count} 条记录, 耗时: #{elapsed.round(2)}秒, 速率: #{rate.round(2)} 条/秒"
  end
  
  def log_performance
    elapsed = Time.current - @start_time
    rate = @record_count / elapsed if elapsed > 0
    
    Rails.logger.info "导入完成:"
    Rails.logger.info "  总记录数: #{@record_count}"
    Rails.logger.info "  总耗时: #{elapsed.round(2)}秒"
    Rails.logger.info "  平均速率: #{rate.round(2)} 条/秒"
    
    # 记录到数据库用于分析
    ImportPerformance.create!(
      record_count: @record_count,
      elapsed_time: elapsed,
      records_per_second: rate,
      import_date: Time.current
    )
  end
end
```

### 4.2 动态批处理大小调整

```ruby
# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  attr_accessor :batch_size
  
  def initialize(file_path, options = {})
    @file_path = file_path
    @connection = FeeDetail.connection
    @batch_size = options[:batch_size] || 1000
    @performance_samples = []
  end
  
  private
  
  def import_data
    # ... 其他代码
    
    spreadsheet.each_row_streaming(offset: 1) do |row|
      batch_start = Time.current
      
      fee_detail = build_fee_detail_from_row(row)
      batch << fee_detail
      @record_count += 1
      
      if batch.size >= @batch_size
        FeeDetail.insert_all(batch)
        
        # 测量批处理性能
        batch_time = Time.current - batch_start
        @performance_samples << {
          batch_size: batch.size,
          batch_time: batch_time,
          records_per_second: batch.size / batch_time
        }
        
        # 动态调整批处理大小
        adjust_batch_size
        
        batch = []
        log_progress
      end
    end
    
    # ... 其他代码
  end
  
  def adjust_batch_size
    # 保留最近5个样本
    @performance_samples = @performance_samples.last(5)
    
    if @performance_samples.size >= 3
      avg_performance = @performance_samples.sum { |s| s[:records_per_second] } / @performance_samples.size
      
      # 根据性能调整批处理大小
      if avg_performance > 5000 && @batch_size < 5000
        @batch_size = [@batch_size * 1.2, 5000].min.to_i
      elsif avg_performance < 1000 && @batch_size > 100
        @batch_size = [@batch_size * 0.8, 100].max.to_i
      end
    end
  end
end
```

## 5. 预期性能提升

基于SQLite优化案例的经验，结合我们的Rails实现，预期性能提升如下：

1. **基础性能**：当前约85条/秒
2. **事务优化**：提升至23,000条/秒（270倍提升）
3. **预处理语句**：提升至53,000条/秒（2.3倍提升）
4. **SQLite配置优化**：提升至72,000条/秒（1.36倍提升）
5. **索引优化**：提升至96,000条/秒（1.33倍提升）
6. **Excel读取优化**：额外提升20-30%

**总体预期**：从当前性能提升约1000-1200倍，达到每秒10万条以上的导入速度。

## 6. 实施建议

### 6.1 分阶段实施

1. **第一阶段**：实施事务优化和预处理语句（预计提升300倍）
2. **第二阶段**：添加SQLite配置优化（预计额外提升1.5倍）
3. **第三阶段**：实施索引优化策略（预计额外提升1.3倍）
4. **第四阶段**：优化Excel文件读取和动态批处理（预计额外提升1.3倍）

### 6.2 风险控制

1. **数据备份**：在实施优化前，确保有完整的数据备份
2. **测试环境**：先在测试环境验证优化效果
3. **逐步部署**：采用灰度发布策略，逐步应用到生产环境
4. **监控报警**：设置性能监控和异常报警机制

### 6.3 回滚方案

1. **配置回滚**：保存原始SQLite配置，必要时可以快速恢复
2. **代码回滚**：使用版本控制系统，可以快速回退到原始代码
3. **数据恢复**：准备数据恢复脚本，确保数据安全

## 7. 总结

本方案基于SQLite性能优化案例的经验，结合Rails项目的特点，设计了一套完整的导入优化方案。通过事务优化、预处理语句、SQLite配置优化、索引优化和Excel读取优化等策略，预计可以将导入性能提升1000倍以上。

方案采用分阶段实施策略，确保优化过程的可控性和安全性。同时，通过性能监控和动态调整机制，可以持续优化导入性能。