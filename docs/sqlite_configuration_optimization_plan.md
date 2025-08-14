# SQLite配置优化方案

## 1. 优化背景

针对报销单、费用明细、操作历史记录、快递收单等模块的导入性能问题，我们首先从最简单的SQLite配置优化入手。基于SQLite性能优化案例的经验，通过调整SQLite的PRAGMA设置，可以在不修改业务代码的情况下显著提升导入性能。

## 2. SQLite配置优化策略

### 2.1 核心PRAGMA设置

根据SQLite优化案例，以下PRAGMA设置对导入性能影响最大：

```ruby
# 1. 同步模式优化
PRAGMA synchronous = OFF
# 效果：关闭同步等待，避免每次写入后等待磁盘同步完成
# 性能提升：约1.5倍
# 风险：系统崩溃时可能导致数据损坏

# 2. 日志模式优化
PRAGMA journal_mode = MEMORY
# 效果：将回滚日志存储在内存中，减少磁盘I/O
# 性能提升：约1.2倍
# 风险：系统崩溃时可能导致数据库损坏

# 3. 缓存大小优化
PRAGMA cache_size = 10000
# 效果：增加SQLite缓存大小，减少磁盘读取
# 性能提升：约1.1倍
# 风险：增加内存使用

# 4. 页面大小优化
PRAGMA page_size = 4096
# 效果：增加页面大小，提高读写效率
# 性能提升：约1.1倍
# 风险：增加内存使用

# 5. 临时存储优化
PRAGMA temp_store = MEMORY
# 效果：将临时表存储在内存中
# 性能提升：约1.1倍
# 风险：增加内存使用

# 6. 外键约束优化
PRAGMA foreign_keys = OFF
# 效果：临时关闭外键约束检查
# 性能提升：约1.2倍
# 风险：需要确保数据完整性
```

### 2.2 预期性能提升

综合以上优化设置，预期可以获得约2-3倍的性能提升，且实施简单，风险可控。

## 3. Rails中的实现方案

### 3.1 创建SQLite配置管理器

```ruby
# lib/sqlite_optimization_manager.rb
class SqliteOptimizationManager
  attr_reader :connection, :original_settings

  def initialize(connection = ActiveRecord::Base.connection)
    @connection = connection
    @original_settings = {}
  end

  # 应用优化设置
  def apply_optimization_settings
    return unless sqlite_database?

    # 保存原始设置
    save_original_settings

    # 应用优化设置
    apply_settings({
      synchronous: 'OFF',
      journal_mode: 'MEMORY',
      cache_size: '10000',
      page_size: '4096',
      temp_store: 'MEMORY',
      foreign_keys: 'OFF'
    })

    Rails.logger.info "SQLite optimization settings applied"
  end

  # 恢复原始设置
  def restore_original_settings
    return unless sqlite_database? && @original_settings.any?

    apply_settings(@original_settings)
    Rails.logger.info "SQLite original settings restored"
  end

  # 仅在导入期间应用优化设置
  def during_import
    return yield unless sqlite_database?

    apply_optimization_settings
    result = yield
    restore_original_settings
    result
  end

  private

  def sqlite_database?
    @connection.adapter_name.downcase.include?('sqlite')
  end

  def save_original_settings
    settings_to_save = %w[synchronous journal_mode cache_size page_size temp_store foreign_keys]
    
    settings_to_save.each do |setting|
      @original_settings[setting.to_sym] = @connection.select_value("PRAGMA #{setting}")
    end
  end

  def apply_settings(settings)
    settings.each do |key, value|
      @connection.execute("PRAGMA #{key} = #{value}")
    end
  end
end
```

### 3.2 在导入操作中使用

```ruby
# 在现有的导入方法中使用优化
class ReimbursementImportService
  def initialize(file_path)
    @file_path = file_path
    @optimization_manager = SqliteOptimizationManager.new
  end

  def import
    @optimization_manager.during_import do
      # 现有的导入逻辑
      import_reimbursements
      import_fee_details
      import_operation_histories
      import_express_receipts
    end
  end

  private

  def import_reimbursements
    # 现有的报销单导入逻辑
  end

  def import_fee_details
    # 现有的费用明细导入逻辑
  end

  def import_operation_histories
    # 现有的操作历史记录导入逻辑
  end

  def import_express_receipts
    # 现有的快递收单导入逻辑
  end
end
```

### 3.3 在ActiveAdmin导入中使用

```ruby
# app/admin/reimbursements.rb
ActiveAdmin.register Reimbursement do
  # ... 其他配置

  collection_action :import, method: :post do
    if params[:file].present?
      begin
        optimization_manager = SqliteOptimizationManager.new
        
        optimization_manager.during_import do
          # 现有的导入逻辑
          import_service = ReimbursementImportService.new(params[:file].path)
          import_service.import
        end
        
        redirect_to admin_reimbursements_path, notice: "导入成功"
      rescue => e
        redirect_to admin_reimbursements_path, alert: "导入失败: #{e.message}"
      end
    end
  end
end
```

## 4. 针对不同模块的优化应用

### 4.1 报销单导入优化

```ruby
# app/services/reimbursement_import_service.rb
class ReimbursementImportService
  def import(file_path)
    SqliteOptimizationManager.new.during_import do
      spreadsheet = Roo::Excelx.new(file_path)
      
      Reimbursement.transaction do
        spreadsheet.each_row_streaming(offset: 1) do |row|
          Reimbursement.create!(
            title: row[0],
            amount: row[1],
            # 其他字段...
          )
        end
      end
    end
  end
end
```

### 4.2 费用明细导入优化

```ruby
# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  def import(file_path)
    SqliteOptimizationManager.new.during_import do
      spreadsheet = Roo::Excelx.new(file_path)
      
      FeeDetail.transaction do
        spreadsheet.each_row_streaming(offset: 1) do |row|
          FeeDetail.create!(
            reimbursement_id: row[0],
            fee_type: row[1],
            amount: row[2],
            # 其他字段...
          )
        end
      end
    end
  end
end
```

### 4.3 操作历史记录导入优化

```ruby
# app/services/operation_history_import_service.rb
class OperationHistoryImportService
  def import(file_path)
    SqliteOptimizationManager.new.during_import do
      spreadsheet = Roo::Excelx.new(file_path)
      
      OperationHistory.transaction do
        spreadsheet.each_row_streaming(offset: 1) do |row|
          OperationHistory.create!(
            operation_type: row[0],
            operator_id: row[1],
            operation_time: row[2],
            # 其他字段...
          )
        end
      end
    end
  end
end
```

### 4.4 快递收单导入优化

```ruby
# app/services/express_receipt_import_service.rb
class ExpressReceiptImportService
  def import(file_path)
    SqliteOptimizationManager.new.during_import do
      spreadsheet = Roo::Excelx.new(file_path)
      
      ExpressReceipt.transaction do
        spreadsheet.each_row_streaming(offset: 1) do |row|
          ExpressReceipt.create!(
            tracking_number: row[0],
            express_company: row[1],
            receipt_time: row[2],
            # 其他字段...
          )
        end
      end
    end
  end
end
```

## 5. 全局配置优化（可选）

如果希望在整个应用启动时就应用SQLite优化设置，可以在初始化器中配置：

```ruby
# config/initializers/sqlite_optimization.rb
Rails.application.configure do
  # 仅在开发环境和测试环境应用全局优化
  if Rails.env.development? || Rails.env.test?
    ActiveSupport.on_load(:active_record) do
      if ActiveRecord::Base.connection.adapter_name.downcase.include?('sqlite')
        optimization_manager = SqliteOptimizationManager.new
        optimization_manager.apply_optimization_settings
        
        Rails.logger.info "Global SQLite optimization settings applied"
      end
    end
  end
end
```

## 6. 性能监控

### 6.1 添加性能监控

```ruby
# lib/sqlite_optimization_manager.rb
class SqliteOptimizationManager
  # ... 其他代码

  def during_import_with_monitoring
    return yield unless sqlite_database?

    start_time = Time.current
    apply_optimization_settings
    
    begin
      result = yield
      elapsed_time = Time.current - start_time
      
      Rails.logger.info "Import completed in #{elapsed_time.round(2)} seconds with SQLite optimization"
      
      # 记录性能数据
      ImportPerformance.create!(
        operation_type: 'import_with_sqlite_optimization',
        elapsed_time: elapsed_time,
        record_count: result.try(:size) || 0,
        optimization_settings: @original_settings,
        created_at: Time.current
      )
      
      result
    ensure
      restore_original_settings
    end
  end
end
```

### 6.2 创建性能监控表

```ruby
# db/migrate/xxxxxxxxxxxxxx_create_import_performances.rb
class CreateImportPerformances < ActiveRecord::Migration[6.1]
  def change
    create_table :import_performances do |t|
      t.string :operation_type, null: false
      t.float :elapsed_time, null: false
      t.integer :record_count, default: 0
      t.text :optimization_settings
      t.timestamps
    end
    
    add_index :import_performances, :operation_type
    add_index :import_performances, :created_at
  end
end
```

## 7. 风险控制与回滚方案

### 7.1 数据备份策略

```ruby
# lib/sqlite_optimization_manager.rb
class SqliteOptimizationManager
  # ... 其他代码

  def with_backup
    return yield unless sqlite_database?

    backup_path = create_database_backup
    
    begin
      result = yield
      result
    rescue => e
      restore_database_from_backup(backup_path)
      raise e
    ensure
      delete_backup(backup_path)
    end
  end

  private

  def create_database_backup
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_path = Rails.root.join('tmp', "database_backup_#{timestamp}.sqlite3")
    
    FileUtils.cp(ActiveRecord::Base.connection_config[:database], backup_path)
    Rails.logger.info "Database backup created at #{backup_path}"
    
    backup_path
  end

  def restore_database_from_backup(backup_path)
    return unless File.exist?(backup_path)
    
    FileUtils.cp(backup_path, ActiveRecord::Base.connection_config[:database])
    Rails.logger.info "Database restored from backup"
  end

  def delete_backup(backup_path)
    File.delete(backup_path) if File.exist?(backup_path)
  end
end
```

### 7.2 安全使用示例

```ruby
# 安全的导入示例
class SafeReimbursementImportService
  def import(file_path)
    optimization_manager = SqliteOptimizationManager.new
    
    optimization_manager.with_backup do
      optimization_manager.during_import_with_monitoring do
        # 导入逻辑
        import_service = ReimbursementImportService.new(file_path)
        import_service.import
      end
    end
  end
end
```

## 8. 实施计划

### 8.1 第一阶段：基础优化（1-2天）

1. 创建`SqliteOptimizationManager`类
2. 在报销单导入中应用优化
3. 测试性能提升效果
4. 验证数据完整性

### 8.2 第二阶段：扩展应用（2-3天）

1. 在费用明细导入中应用优化
2. 在操作历史记录导入中应用优化
3. 在快递收单导入中应用优化
4. 添加性能监控

### 8.3 第三阶段：完善与监控（1-2天）

1. 添加数据备份功能
2. 完善错误处理机制
3. 添加性能监控仪表板
4. 编写文档和培训材料

## 9. 预期效果

通过SQLite配置优化，预期可以获得：

1. **性能提升**：导入速度提升2-3倍
2. **实施简单**：无需修改业务逻辑，只需添加优化管理器
3. **风险可控**：通过备份和监控机制确保数据安全
4. **易于扩展**：可以轻松应用到其他模块

## 10. 总结

SQLite配置优化是一种简单而有效的性能优化方法，特别适合作为我们导入性能优化的第一步。通过调整PRAGMA设置，我们可以在不修改业务代码的情况下显著提升导入性能。

这个方案具有实施简单、风险可控、效果明显的特点，可以作为后续更复杂优化（如批量插入、索引优化等）的基础。