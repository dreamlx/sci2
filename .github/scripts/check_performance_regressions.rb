#!/usr/bin/env ruby
# 性能回归检查脚本

require 'json'
require 'fileutils'

# 性能阈值配置
PERFORMANCE_THRESHOLDS = {
  execution_time: {
    warning: 5.0,    # 5秒
    critical: 10.0   # 10秒
  },
  db_queries: {
    warning: 100,    # 100个查询
    critical: 200    # 200个查询
  },
  memory_usage: {
    warning: 50 * 1024 * 1024,   # 50MB
    critical: 100 * 1024 * 1024  # 100MB
  },
  throughput: {
    warning: 10,     # 10 records/sec
    critical: 5      # 5 records/sec
  }
}.freeze

def load_performance_report(report_path)
  return nil unless File.exist?(report_path)

  begin
    JSON.parse(File.read(report_path))
  rescue JSON::ParserError => e
    puts "⚠️  无法解析性能报告: #{e.message}"
    nil
  end
end

def check_thresholds(value, thresholds, metric_name)
  return { status: 'pass' } if value.nil?

  if value >= thresholds[:critical]
    { status: 'critical', value: value, threshold: thresholds[:critical] }
  elsif value >= thresholds[:warning]
    { status: 'warning', value: value, threshold: thresholds[:warning] }
  else
    { status: 'pass', value: value }
  end
end

def analyze_performance(report)
  return { overall_status: 'pass', issues: [] } unless report

  summary = report['summary'] || {}
  issues = []

  # 检查执行时间
  avg_execution_time = summary.dig('execution_time', 'average')
  execution_check = check_thresholds(avg_execution_time, PERFORMANCE_THRESHOLDS[:execution_time], 'execution_time')
  issues << { metric: 'execution_time', **execution_check } if execution_check[:status] != 'pass'

  # 检查数据库查询数
  avg_db_queries = summary.dig('db_queries', 'average')
  db_check = check_thresholds(avg_db_queries, PERFORMANCE_THRESHOLDS[:db_queries], 'db_queries')
  issues << { metric: 'db_queries', **db_check } if db_check[:status] != 'pass'

  # 检查内存使用
  avg_memory = summary.dig('memory_usage', 'average')
  memory_check = check_thresholds(avg_memory, PERFORMANCE_THRESHOLDS[:memory_usage], 'memory_usage')
  issues << { metric: 'memory_usage', **memory_check } if memory_check[:status] != 'pass'

  # 检查吞吐量
  avg_throughput = summary.dig('throughput', 'average')
  throughput_check = check_thresholds(avg_throughput, PERFORMANCE_THRESHOLDS[:throughput], 'throughput')
  if throughput_check[:status] != 'pass' && avg_throughput < PERFORMANCE_THRESHOLDS[:throughput][:critical]
    issues << { metric: 'throughput', status: 'critical', value: avg_throughput, threshold: PERFORMANCE_THRESHOLDS[:throughput][:critical] }
  elsif throughput_check[:status] != 'pass'
    issues << { metric: 'throughput', status: 'warning', value: avg_throughput, threshold: PERFORMANCE_THRESHOLDS[:throughput][:warning] }
  end

  # 检查推荐的高优先级问题
  recommendations = report['recommendations'] || []
  high_priority_issues = recommendations.select { |r| r['priority'] == 'high' }
  high_priority_issues.each do |issue|
    issues << {
      metric: 'recommendation',
      status: 'warning',
      title: issue['title'],
      description: issue['description']
    }
  end

  overall_status = if issues.any? { |i| i[:status] == 'critical' }
                     'critical'
                   elsif issues.any? { |i| i[:status] == 'warning' }
                     'warning'
                   else
                     'pass'
                   end

  {
    overall_status: overall_status,
    issues: issues,
    summary: summary
  }
end

def generate_performance_badge(overall_status)
  case overall_status
  when 'critical'
    { color: 'red', message: 'Critical' }
  when 'warning'
    { color: 'yellow', message: 'Warning' }
  else
    { color: 'brightgreen', message: 'Pass' }
  end
end

def main
  puts "🚀 开始性能回归检查..."

  report_path = 'tmp/performance_reports/ci_performance_report.json'
  report = load_performance_report(report_path)

  unless report
    puts "❌ 未找到性能报告文件: #{report_path}"
    exit 1
  end

  analysis = analyze_performance(report)
  badge = generate_performance_badge(analysis[:overall_status])

  puts "\n📊 性能分析结果:"
  puts "总体状态: #{analysis[:overall_status].upcase}"
  puts "执行时间: #{analysis[:summary]&.dig('execution_time', 'average')&.round(3)}s"
  puts "数据库查询: #{analysis[:summary]&.dig('db_queries', 'average')&.to_i}"
  puts "内存使用: #{(analysis[:summary]&.dig('memory_usage', 'average') || 0) / 1024 / 1024}MB"
  puts "吞吐量: #{analysis[:summary]&.dig('throughput', 'average')&.to_i} records/sec"

  if analysis[:issues].any?
    puts "\n⚠️  发现的问题:"
    analysis[:issues].each do |issue|
      case issue[:status]
      when 'critical'
        puts "  🔴 #{issue[:metric]}: #{issue[:value]} (阈值: #{issue[:threshold]})"
      when 'warning'
        puts "  🟡 #{issue[:metric]}: #{issue[:value]} (阈值: #{issue[:threshold]})"
      end
      puts "     #{issue[:description]}" if issue[:description]
    end
  end

  # 生成性能徽章数据
  badge_data = {
    schemaVersion: 1,
    label: 'Performance',
    message: badge[:message],
    color: badge[:color]
  }

  File.write('tmp/performance_badge.json', JSON.pretty_generate(badge_data))
  puts "\n🏷️  性能徽章已生成: tmp/performance_badge.json"

  # 设置退出码
  case analysis[:overall_status]
  when 'critical'
    puts "\n❌ 性能测试失败: 发现严重性能问题"
    exit 1
  when 'warning'
    puts "\n⚠️  性能测试警告: 发现性能问题需要关注"
    exit 0
  else
    puts "\n✅ 性能测试通过"
    exit 0
  end
end

if __FILE__ == $0
  main
end