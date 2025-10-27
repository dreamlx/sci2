#!/usr/bin/env ruby
# 性能对比脚本 - 比较基线分支和当前分支的性能差异

require 'json'
require 'fileutils'

def load_report(directory)
  report_path = File.join(directory, 'ci_performance_report.json')
  return nil unless File.exist?(report_path)

  JSON.parse(File.read(report_path))
end

def calculate_percentage_change(old_value, new_value)
  return 0 if old_value == 0
  ((new_value - old_value) / old_value.to_f * 100).round(2)
end

def compare_metrics(baseline, current)
  baseline_summary = baseline&.dig('summary') || {}
  current_summary = current&.dig('summary') || {}

  comparisons = {}

  # 执行时间对比
  baseline_time = baseline_summary.dig('execution_time', 'average') || 0
  current_time = current_summary.dig('execution_time', 'average') || 0
  time_change = calculate_percentage_change(baseline_time, current_time)
  comparisons[:execution_time] = {
    baseline: baseline_time,
    current: current_time,
    change_percentage: time_change,
    status: determine_status(time_change, :lower_is_better)
  }

  # 数据库查询对比
  baseline_queries = baseline_summary.dig('db_queries', 'average') || 0
  current_queries = current_summary.dig('db_queries', 'average') || 0
  queries_change = calculate_percentage_change(baseline_queries, current_queries)
  comparisons[:db_queries] = {
    baseline: baseline_queries,
    current: current_queries,
    change_percentage: queries_change,
    status: determine_status(queries_change, :lower_is_better)
  }

  # 内存使用对比
  baseline_memory = baseline_summary.dig('memory_usage', 'average') || 0
  current_memory = current_summary.dig('memory_usage', 'average') || 0
  memory_change = calculate_percentage_change(baseline_memory, current_memory)
  comparisons[:memory_usage] = {
    baseline: baseline_memory,
    current: current_memory,
    change_percentage: memory_change,
    status: determine_status(memory_change, :lower_is_better)
  }

  # 吞吐量对比
  baseline_throughput = baseline_summary.dig('throughput', 'average') || 0
  current_throughput = current_summary.dig('throughput', 'average') || 0
  throughput_change = calculate_percentage_change(baseline_throughput, current_throughput)
  comparisons[:throughput] = {
    baseline: baseline_throughput,
    current: current_throughput,
    change_percentage: throughput_change,
    status: determine_status(throughput_change, :higher_is_better)
  }

  comparisons
end

def determine_status(change_percentage, direction)
  case direction
  when :lower_is_better
    if change_percentage > 20
      'regression'
    elsif change_percentage > 10
      'warning'
    elsif change_percentage < -10
      'improvement'
    else
      'stable'
    end
  when :higher_is_better
    if change_percentage < -20
      'regression'
    elsif change_percentage < -10
      'warning'
    elsif change_percentage > 10
      'improvement'
    else
      'stable'
    end
  end
end

def generate_comparison_report(baseline_dir, current_dir, output_dir)
  baseline_report = load_report(baseline_dir)
  current_report = load_report(current_dir)

  unless baseline_report && current_report
    puts "❌ 缺少性能报告文件"
    puts "基线报告: #{baseline_dir}/ci_performance_report.json - #{File.exist?(baseline_dir + '/ci_performance_report.json') ? '存在' : '不存在'}"
    puts "当前报告: #{current_dir}/ci_performance_report.json - #{File.exist?(current_dir + '/ci_performance_report.json') ? '存在' : '不存在'}"
    return
  end

  comparisons = compare_metrics(baseline_report, current_report)

  # 确定总体状态
  statuses = comparisons.values.map { |v| v[:status] }
  overall_status = if statuses.include?('regression')
                     'regression'
                   elsif statuses.include?('warning')
                     'warning'
                   elsif statuses.include?('improvement')
                     'improvement'
                   else
                     'stable'
                   end

  comparison_report = {
    generated_at: Time.current.iso8601,
    baseline_branch: ENV.fetch('GITHUB_BASE_REF', 'main'),
    current_branch: ENV.fetch('GITHUB_HEAD_REF', 'feature-branch'),
    overall_status: overall_status,
    comparisons: comparisons,
    recommendations: generate_recommendations(comparisons),
    detailed_results: {
      baseline: baseline_report,
      current: current_report
    }
  }

  # 保存对比报告
  FileUtils.mkdir_p(output_dir)
  output_file = File.join(output_dir, 'performance_comparison.json')
  File.write(output_file, JSON.pretty_generate(comparison_report))

  puts "📊 性能对比报告已生成: #{output_file}"

  # 输出摘要
  puts "\n📈 性能对比摘要:"
  puts "总体状态: #{overall_status.upcase}"
  comparisons.each do |metric, data|
    status_icon = case data[:status]
                  when 'regression' then '🔴'
                  when 'warning' then '🟡'
                  when 'improvement' then '🟢'
                  else '⚪'
                  end
    change_symbol = data[:change_percentage] >= 0 ? '+' : ''
    puts "  #{status_icon} #{metric.to_s.gsub('_', ' ').titleize}: #{change_symbol}#{data[:change_percentage]}%"
  end

  if overall_status == 'regression'
    puts "\n⚠️  检测到性能回归，请检查相关变更"
    exit 1
  elsif overall_status == 'warning'
    puts "\n⚠️  性能有轻微下降，建议关注"
    exit 0
  else
    puts "\n✅ 性能稳定或有所改善"
    exit 0
  end
end

def generate_recommendations(comparisons)
  recommendations = []

  comparisons.each do |metric, data|
    case data[:status]
    when 'regression'
      recommendations << {
        metric: metric,
        type: 'regression',
        priority: 'high',
        message: "#{metric_to_human_readable(metric)}显著增加(#{data[:change_percentage]}%)，需要立即优化",
        suggestions: get_regression_suggestions(metric)
      }
    when 'warning'
      recommendations << {
        metric: metric,
        type: 'warning',
        priority: 'medium',
        message: "#{metric_to_human_readable(metric)}有所增加(#{data[:change_percentage]}%)，建议关注",
        suggestions: get_warning_suggestions(metric)
      }
    when 'improvement'
      recommendations << {
        metric: metric,
        type: 'improvement',
        priority: 'low',
        message: "#{metric_to_human_readable(metric)}有所改善(#{data[:change_percentage]}%)",
        suggestions: ["继续保持当前的优化策略"]
      }
    end
  end

  recommendations
end

def metric_to_human_readable(metric)
  case metric
  when :execution_time then '执行时间'
  when :db_queries then '数据库查询数'
  when :memory_usage then '内存使用'
  when :throughput then '吞吐量'
  else metric.to_s.gsub('_', ' ').titleize
  end
end

def get_regression_suggestions(metric)
  case metric
  when :execution_time
    [
      "检查是否引入了新的复杂算法或循环",
      "审查数据库查询是否出现了N+1问题",
      "验证是否有不必要的计算或数据处理",
      "考虑添加适当的缓存"
    ]
  when :db_queries
    [
      "检查是否引入了N+1查询问题",
      "使用includes或joins预加载关联数据",
      "审查是否可以合并多个查询为单个查询",
      "考虑使用查询缓存"
    ]
  when :memory_usage
    [
      "检查是否有内存泄漏（未释放的对象或连接）",
      "审查是否缓存了过多的数据",
      "验证大数据集的处理是否使用了流式处理",
      "检查是否有循环引用导致对象无法回收"
    ]
  when :throughput
    [
      "吞吐量下降通常与执行时间增加相关",
      "检查并优化执行时间相关的瓶颈",
      "考虑并行处理或异步处理"
    ]
  else
    ["检查相关的代码变更，识别性能瓶颈"]
  end
end

def get_warning_suggestions(metric)
  get_regression_suggestions(metric).map { |s| s + "（轻微问题）" }
end

# 主程序
def main
  baseline_dir = ARGV[0] || 'baseline_reports'
  current_dir = ARGV[1] || 'current_reports'
  output_dir = ARGV[2] || 'performance_comparison_output'

  puts "🔍 开始性能对比分析..."
  puts "基线目录: #{baseline_dir}"
  puts "当前目录: #{current_dir}"
  puts "输出目录: #{output_dir}"

  generate_comparison_report(baseline_dir, current_dir, output_dir)
end

if __FILE__ == $0
  main
end