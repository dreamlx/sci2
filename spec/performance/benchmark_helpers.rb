# spec/performance/benchmark_helpers.rb
# 性能测试辅助工具模块

module BenchmarkHelpers
  require 'benchmark'
  require 'memory_profiler'
  require 'active_support/core_ext/numeric/time'

  # 性能测试结果类
  class PerformanceResult
    attr_accessor :test_name, :execution_time, :memory_usage, :db_queries,
                  :records_processed, :errors_count, :metadata

    def initialize(test_name)
      @test_name = test_name
      @metadata = {}
    end

    def to_h
      {
        test_name: @test_name,
        execution_time: @execution_time,
        memory_usage: @memory_usage,
        db_queries: @db_queries,
        records_processed: @records_processed,
        errors_count: @errors_count,
        throughput: calculate_throughput,
        metadata: @metadata
      }
    end

    def calculate_throughput
      return 0 if @execution_time.nil? || @records_processed.nil? || @execution_time == 0
      (@records_processed.to_f / @execution_time).round(2)
    end
  end

  # 性能基准测试执行器
  def benchmark_performance(test_name, options = {})
    result = PerformanceResult.new(test_name)

    # 设置默认选项
    warmup_iterations = options[:warmup_iterations] || 1
    iterations = options[:iterations] || 1
    gc_before = options[:gc_before] != false

    # 预热
    warmup_iterations.times { yield if block_given? }

    # 执行基准测试
    result.db_queries = []
    result.memory_usage = {}

    # 内存和查询监控
    memory_report = nil
    query_count = 0

    benchmark_result = Benchmark.measure do

      # 内存分析
      if options[:profile_memory]
        memory_report = MemoryProfiler.report do
          query_count = count_db_queries do
            iterations.times { yield if block_given? }
          end
        end
      else
        query_count = count_db_queries do
          iterations.times { yield if block_given? }
        end
      end

    end

    # 处理结果
    result.execution_time = benchmark_result.real / iterations
    result.db_queries = query_count / iterations

    if memory_report
      result.memory_usage = {
        total_allocated: memory_report.total_allocated_memsize,
        total_retained: memory_report.total_retained_memsize,
        allocated_objects: memory_report.total_allocated,
        retained_objects: memory_report.total_retained
      }
    end

    result
  end

  # 数据库查询计数器
  def count_db_queries
    query_count = 0
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      query_count += 1
    end

    yield if block_given?

    ActiveSupport::Notifications.unsubscribe(subscriber)
    query_count
  end

  # 生成测试数据
  def generate_test_data(count, type = :reimbursement, thread_id = nil)
    thread_prefix = thread_id ? "T#{thread_id}_" : ""

    case type
    when :reimbursement
      (1..count).map do |i|
        {
          invoice_number: "#{thread_prefix}INV#{format('%06d', i + (thread_id || 0) * 1000)}",
          applicant_name: "#{thread_prefix}测试用户#{i}",
          department: %w[技术部 财务部 市场部 人事部].sample,
          amount: rand(100.0..10000.0).round(2),
          description: "#{thread_prefix}测试费用报销#{i}",
          application_date: rand(1..30).days.ago.to_date,
          expense_type: %w[差旅费 办公费 招待费 培训费].sample,
          project_code: "#{thread_prefix}PROJ#{format('%03d', rand(1..100))}"
        }
      end
    when :express_receipt
      reimbursements = Reimbursement.limit(count)
      (1..count).map do |i|
        reimbursement = reimbursements.sample || Reimbursement.first
        {
          document_number: reimbursement&.invoice_number || "INV#{format('%06d', i)}",
          tracking_number: "SF#{rand(1000000000..9999999999)}",
          operation_notes: "快递收单操作#{i}",
          received_at: rand(1..7).days.ago,
          filling_id: "FILL#{format('%08d', i)}"
        }
      end
    else
      []
    end
  end

  # 创建测试文件
  def create_test_file(data, filename = "test_import.csv")
    temp_file = Tempfile.new([filename, '.csv'])

    if data.any?
      headers = data.first.keys
      CSV.open(temp_file.path, 'w') do |csv|
        csv << headers
        data.each { |row| csv << row.values }
      end
    end

    temp_file.close
    temp_file
  end

  # 清理测试数据
  def cleanup_test_data
    Reimbursement.where("invoice_number LIKE 'INV%'").delete_all
    ExpressReceiptWorkOrder.where("tracking_number LIKE 'SF%'").delete_all
    WorkOrder.joins(:reimbursement).where("reimbursements.invoice_number LIKE 'INV%'").delete_all
  end

  # 性能阈值检查
  def check_performance_thresholds(result, thresholds)
    warnings = []
    errors = []

    thresholds.each do |metric, threshold|
      value = result.send(metric) || result.to_h[metric]

      case metric
      when :execution_time
        if value > threshold
          errors << "执行时间 #{value}s 超过阈值 #{threshold}s"
        end
      when :db_queries
        if value > threshold
          warnings << "数据库查询数 #{value} 超过建议值 #{threshold}"
        end
      when :memory_usage
        if value.is_a?(Hash) && value[:total_allocated] && value[:total_allocated] > threshold
          warnings << "内存分配 #{value[:total_allocated]} bytes 超过建议值 #{threshold}"
        end
      end
    end

    { warnings: warnings, errors: errors }
  end

  # 并发测试执行器
  def benchmark_concurrency(thread_count, options = {})
    threads = []
    results = []
    mutex = Mutex.new

    thread_count.times do |i|
      threads << Thread.new do
        thread_result = yield(i) if block_given?

        mutex.synchronize do
          results << thread_result
        end
      end
    end

    threads.each(&:join)
    results
  end

  # 系统资源监控
  def monitor_system_resources
    {
      cpu_usage: get_cpu_usage,
      memory_usage: get_memory_usage,
      db_connections: get_db_connections,
      disk_io: get_disk_io_stats
    }
  end

  private

  def get_cpu_usage
    # 简单的CPU使用率获取（可根据系统调整）
    begin
      `ps -o %cpu= -p #{Process.pid}`.strip.to_f
    rescue
      0.0
    end
  end

  def get_memory_usage
    begin
      status = `ps -o rss= -p #{Process.pid}`.strip.to_i
      status * 1024 # 转换为bytes
    rescue
      0
    end
  end

  def get_db_connections
    begin
      ActiveRecord::Base.connection_pool.stat[:busy] +
      ActiveRecord::Base.connection_pool.stat[:idle]
    rescue
      0
    end
  end

  def get_disk_io_stats
    # 简化版本，实际可根据需要实现
    { read_bytes: 0, write_bytes: 0 }
  end

  # Rails Logger 重定向用于捕获测试日志
  def with_captured_logs
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    yield if block_given?

    log_output.string
  ensure
    Rails.logger = original_logger
  end
end