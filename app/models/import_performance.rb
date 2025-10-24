class ImportPerformance < ApplicationRecord
  validates :operation_type, presence: true
  validates :elapsed_time, presence: true, numericality: { greater_than: 0 }
  validates :record_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :by_operation_type, ->(type) { where(operation_type: type) }
  scope :by_optimization_level, ->(level) { where(optimization_level: level) }
  scope :recent, -> { order(created_at: :desc) }

  # 计算每秒处理记录数
  def records_per_second
    return 0 if elapsed_time.zero? || record_count.zero?

    (record_count / elapsed_time).round(2)
  end

  # 格式化耗时
  def formatted_elapsed_time
    "#{elapsed_time.round(2)}秒"
  end

  # 解析优化设置
  def parsed_optimization_settings
    return {} unless optimization_settings.present?

    JSON.parse(optimization_settings)
  rescue JSON::ParserError
    {}
  end

  # 性能等级评估
  def performance_grade
    rps = records_per_second
    case rps
    when 0..50
      'C'
    when 51..100
      'B'
    when 101..200
      'A'
    else
      'S'
    end
  end

  # 类方法：获取性能统计
  def self.performance_stats(operation_type = nil)
    scope = operation_type ? by_operation_type(operation_type) : all

    {
      total_imports: scope.count,
      avg_elapsed_time: scope.average(:elapsed_time)&.round(2) || 0,
      avg_records_per_second: scope.joins('').select('AVG(record_count / elapsed_time) as avg_rps').first&.avg_rps&.round(2) || 0,
      total_records: scope.sum(:record_count),
      optimization_levels: scope.group(:optimization_level).count
    }
  end
end
