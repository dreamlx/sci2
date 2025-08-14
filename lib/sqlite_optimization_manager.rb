# lib/sqlite_optimization_manager.rb
class SqliteOptimizationManager
  # 优化级别定义
  SAFE_SETTINGS = {
    cache_size: '10000',        # 增加缓存大小到10MB
    temp_store: 'MEMORY'        # 临时表存储在内存中
  }.freeze
  
  MODERATE_SETTINGS = SAFE_SETTINGS.merge({
    synchronous: 'NORMAL',      # 平衡性能和安全性
    journal_mode: 'WAL',        # Write-Ahead Logging模式
    foreign_keys: 'OFF'         # 导入期间关闭外键约束
  }).freeze
  
  AGGRESSIVE_SETTINGS = MODERATE_SETTINGS.merge({
    synchronous: 'OFF',         # 关闭同步等待（高风险）
    journal_mode: 'MEMORY',     # 日志存储在内存中（高风险）
    cache_size: '20000'         # 增加缓存到20MB
  }).freeze

  attr_reader :connection, :original_settings, :level

  def initialize(connection = ActiveRecord::Base.connection, level: :safe)
    @connection = connection
    @level = level
    @original_settings = {}
    @settings = case level
                when :safe then SAFE_SETTINGS
                when :moderate then MODERATE_SETTINGS  
                when :aggressive then AGGRESSIVE_SETTINGS
                else raise ArgumentError, "Invalid optimization level: #{level}. Valid levels: :safe, :moderate, :aggressive"
                end
  end

  # 在导入期间应用优化设置，带性能监控
  def during_import_with_monitoring(&block)
    return yield unless sqlite_database?

    start_time = Time.current
    
    # 根据优化级别决定是否需要备份
    if requires_backup?
      with_backup { perform_optimized_import(start_time, &block) }
    else
      perform_optimized_import(start_time, &block)
    end
  end

  # 简化版本，仅应用优化设置
  def during_import(&block)
    return yield unless sqlite_database?

    apply_optimization_settings
    
    begin
      result = yield
      Rails.logger.info "Import completed with #{@level} SQLite optimization"
      result
    ensure
      restore_original_settings
    end
  end

  # 获取当前数据库信息
  def database_info
    return {} unless sqlite_database?
    
    {
      adapter: @connection.adapter_name,
      database_path: database_path,
      current_settings: current_pragma_settings,
      optimization_level: @level
    }
  end

  private

  def requires_backup?
    @level == :aggressive
  end

  def perform_optimized_import(start_time, &block)
    apply_optimization_settings
    
    begin
      result = yield
      log_performance_metrics(start_time, result)
      result
    ensure
      restore_original_settings
    end
  end

  def with_backup(&block)
    backup_path = create_database_backup
    
    begin
      result = yield
      result
    rescue => e
      Rails.logger.error "Import failed, restoring from backup: #{e.message}"
      restore_database_from_backup(backup_path)
      raise e
    ensure
      delete_backup(backup_path)
    end
  end

  def sqlite_database?
    @connection.adapter_name.downcase.include?('sqlite')
  end

  def apply_optimization_settings
    save_original_settings
    
    @settings.each do |key, value|
      execute_pragma(key, value)
    end
    
    Rails.logger.info "SQLite optimization settings applied (level: #{@level})"
    Rails.logger.debug "Applied settings: #{@settings}"
  end

  def save_original_settings
    @settings.keys.each do |setting|
      begin
        @original_settings[setting] = @connection.select_value("PRAGMA #{setting}")
      rescue => e
        Rails.logger.warn "Could not save original setting for #{setting}: #{e.message}"
      end
    end
  end

  def restore_original_settings
    return unless @original_settings.any?

    @original_settings.each do |key, value|
      execute_pragma(key, value) if value.present?
    end
    
    Rails.logger.info "SQLite original settings restored"
  end

  def execute_pragma(key, value)
    sql = "PRAGMA #{key} = #{value}"
    @connection.execute(sql)
    Rails.logger.debug "Executed: #{sql}"
  rescue => e
    Rails.logger.error "Failed to execute PRAGMA #{key} = #{value}: #{e.message}"
  end

  def log_performance_metrics(start_time, result)
    elapsed_time = Time.current - start_time
    record_count = extract_record_count(result)
    records_per_second = record_count > 0 ? (record_count / elapsed_time).round(2) : 0
    
    Rails.logger.info "Import Performance Summary:"
    Rails.logger.info "  - Duration: #{elapsed_time.round(2)} seconds"
    Rails.logger.info "  - Records processed: #{record_count}"
    Rails.logger.info "  - Records per second: #{records_per_second}"
    Rails.logger.info "  - Optimization level: #{@level}"
    
    # 记录性能数据到数据库（如果表存在）
    create_performance_record(elapsed_time, record_count) if performance_table_exists?
  end

  def extract_record_count(result)
    case result
    when Hash
      # 处理导入服务返回的结果格式
      (result[:created] || 0) + (result[:updated] || 0) + (result[:imported] || 0)
    when Integer
      result
    when Array
      result.size
    else
      0
    end
  end

  def performance_table_exists?
    @connection.table_exists?('import_performances')
  end

  def create_performance_record(elapsed_time, record_count)
    begin
      @connection.execute(<<~SQL)
        INSERT INTO import_performances (
          operation_type, elapsed_time, record_count, 
          optimization_level, optimization_settings, created_at, updated_at
        ) VALUES (
          'sqlite_optimized_import', #{elapsed_time}, #{record_count},
          '#{@level}', '#{@settings.to_json}', 
          '#{Time.current.to_s(:db)}', '#{Time.current.to_s(:db)}'
        )
      SQL
    rescue => e
      Rails.logger.warn "Could not create performance record: #{e.message}"
    end
  end

  def current_pragma_settings
    settings = {}
    @settings.keys.each do |key|
      begin
        settings[key] = @connection.select_value("PRAGMA #{key}")
      rescue => e
        settings[key] = "Error: #{e.message}"
      end
    end
    settings
  end

  def database_path
    config = Rails.configuration.database_configuration[Rails.env]
    config['database'] if config
  end

  def create_database_backup
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_path = Rails.root.join('tmp', "database_backup_#{timestamp}.sqlite3")
    
    db_path = database_path
    return nil unless db_path && File.exist?(db_path)
    
    FileUtils.mkdir_p(File.dirname(backup_path))
    FileUtils.cp(db_path, backup_path)
    
    Rails.logger.info "Database backup created at #{backup_path}"
    backup_path
  end

  def restore_database_from_backup(backup_path)
    return unless backup_path && File.exist?(backup_path)
    
    db_path = database_path
    return unless db_path
    
    FileUtils.cp(backup_path, db_path)
    Rails.logger.info "Database restored from backup: #{backup_path}"
  end

  def delete_backup(backup_path)
    return unless backup_path && File.exist?(backup_path)
    
    File.delete(backup_path)
    Rails.logger.debug "Backup file deleted: #{backup_path}"
  rescue => e
    Rails.logger.warn "Could not delete backup file #{backup_path}: #{e.message}"
  end
end