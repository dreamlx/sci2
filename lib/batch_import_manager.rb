# lib/batch_import_manager.rb
class BatchImportManager
  BATCH_SIZE = 1000  # 批量处理大小
  
  attr_reader :model_class, :optimization_level, :sqlite_manager
  
  def initialize(model_class, optimization_level: :moderate)
    @model_class = model_class
    @optimization_level = optimization_level
    @sqlite_manager = SqliteOptimizationManager.new(level: optimization_level)
    @performance_stats = {
      total_processed: 0,
      batches_processed: 0,
      start_time: nil,
      end_time: nil
    }
  end
  
  # 批量导入主方法
  def batch_import(data_array, &block)
    @performance_stats[:start_time] = Time.current
    @performance_stats[:total_processed] = data_array.size
    
    Rails.logger.info "Starting batch import for #{@model_class.name}: #{data_array.size} records"
    
    @sqlite_manager.during_import do
      with_optimized_settings do
        result = process_in_batches(data_array, &block)
        @performance_stats[:end_time] = Time.current
        log_performance_summary
        result
      end
    end
  end
  
  # 带回调禁用的批量导入
  def batch_import_with_disabled_callbacks(data_array, disabled_callbacks = [], &block)
    @performance_stats[:start_time] = Time.current
    @performance_stats[:total_processed] = data_array.size
    
    Rails.logger.info "Starting optimized batch import for #{@model_class.name}: #{data_array.size} records"
    
    @sqlite_manager.during_import do
      with_disabled_callbacks(disabled_callbacks) do
        result = process_in_batches(data_array, &block)
        @performance_stats[:end_time] = Time.current
        log_performance_summary
        result
      end
    end
  end
  
  # 批量插入新记录
  def batch_insert(records_data)
    return 0 if records_data.empty?
    
    # 添加时间戳
    timestamped_data = records_data.map do |record|
      record.merge(
        created_at: Time.current,
        updated_at: Time.current
      )
    end
    
    # 使用原始 SQL 插入来完全避免 ActiveRecord 回调
    table_name = @model_class.table_name
    columns = timestamped_data.first.keys
    column_names = columns.join(', ')
    
    # 构建批量插入的 SQL
    values_sql = timestamped_data.map do |record|
      values = columns.map { |col| ActiveRecord::Base.connection.quote(record[col]) }
      "(#{values.join(', ')})"
    end.join(', ')
    
    sql = "INSERT INTO #{table_name} (#{column_names}) VALUES #{values_sql}"
    ActiveRecord::Base.connection.execute(sql)
    
    Rails.logger.info "Batch inserted #{records_data.size} #{@model_class.name} records using raw SQL"
    records_data.size
  end
  
  # 批量更新现有记录
  def batch_update(records_data, unique_by: :id)
    return 0 if records_data.empty?
    
    # 添加更新时间戳
    timestamped_data = records_data.map do |record|
      record.merge(updated_at: Time.current)
    end
    
    @model_class.upsert_all(timestamped_data, unique_by: unique_by)
    Rails.logger.info "Batch updated #{records_data.size} #{@model_class.name} records"
    records_data.size
  end
  
  # 批量查询现有记录
  def batch_find_existing(field_name, values)
    return {} if values.empty?
    
    @model_class.where(field_name => values.uniq)
                .index_by { |record| record.send(field_name) }
  end
  
  # 获取性能统计
  def performance_stats
    return @performance_stats unless @performance_stats[:end_time]
    
    duration = @performance_stats[:end_time] - @performance_stats[:start_time]
    records_per_second = @performance_stats[:total_processed] / duration
    
    @performance_stats.merge(
      duration: duration.round(3),
      records_per_second: records_per_second.round(2)
    )
  end
  
  private
  
  def with_optimized_settings(&block)
    # 这里可以添加额外的优化设置
    # 比如临时调整ActiveRecord的配置
    original_logger_level = Rails.logger.level
    
    begin
      # 在批量导入期间减少日志输出
      Rails.logger.level = Logger::WARN if Rails.env.production?
      yield
    ensure
      Rails.logger.level = original_logger_level
    end
  end
  
  def with_disabled_callbacks(disabled_callbacks, &block)
    return yield if disabled_callbacks.empty?
    
    # 禁用指定的回调
    disabled_callbacks.each do |callback_info|
      callback_type, timing, method_name = callback_info
      @model_class.skip_callback(callback_type, timing, method_name)
    end
    
    Rails.logger.info "Disabled #{disabled_callbacks.size} callbacks for #{@model_class.name}"
    
    begin
      yield
    ensure
      # 恢复回调
      disabled_callbacks.each do |callback_info|
        callback_type, timing, method_name = callback_info
        @model_class.set_callback(callback_type, timing, method_name)
      end
      
      Rails.logger.info "Restored #{disabled_callbacks.size} callbacks for #{@model_class.name}"
    end
  end
  
  def process_in_batches(data_array, &block)
    results = []
    
    data_array.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
      Rails.logger.info "Processing batch #{batch_index + 1}/#{(data_array.size.to_f / BATCH_SIZE).ceil} (#{batch.size} records)"
      
      batch_result = ActiveRecord::Base.transaction do
        yield(batch)
      end
      
      results << batch_result
      @performance_stats[:batches_processed] += 1
    end
    
    results
  end
  
  def log_performance_summary
    stats = performance_stats
    
    Rails.logger.info "Batch import completed for #{@model_class.name}:"
    Rails.logger.info "  - Total records: #{stats[:total_processed]}"
    Rails.logger.info "  - Batches processed: #{stats[:batches_processed]}"
    Rails.logger.info "  - Duration: #{stats[:duration]} seconds"
    Rails.logger.info "  - Speed: #{stats[:records_per_second]} records/second"
    Rails.logger.info "  - Optimization level: #{@optimization_level}"
  end
end