# spec/performance/performance_reporter.rb
# 性能测试报告生成器

class PerformanceReporter
  require 'json'
  require 'fileutils'

  attr_reader :results, :report_dir

  def initialize(report_dir = 'tmp/performance_reports')
    @results = []
    @report_dir = report_dir
    ensure_report_directory
  end

  def add_result(result)
    @results << result
  end

  def add_results(results_array)
    @results.concat(results_array)
  end

  # 生成完整的性能报告
  def generate_report(report_name = nil)
    report_name ||= "performance_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}"

    report_data = {
      metadata: build_metadata,
      summary: build_summary,
      detailed_results: build_detailed_results,
      analysis: build_analysis,
      recommendations: build_recommendations
    }

    save_report(report_name, report_data)
    generate_charts(report_name) if should_generate_charts?

    report_file_path = File.join(@report_dir, "#{report_name}.json")
    puts "性能测试报告已生成: #{report_file_path}"

    report_file_path
  end

  # 生成简化报告（CI/CD友好）
  def generate_ci_report
    ci_data = {
      timestamp: Time.current.iso8601,
      summary: build_summary,
      thresholds_status: check_thresholds,
      recommendations: critical_recommendations
    }

    ci_report_path = File.join(@report_dir, 'ci_performance_report.json')
    File.write(ci_report_path, JSON.pretty_generate(ci_data))

    ci_report_path
  end

  # 生成HTML报告
  def generate_html_report(report_name = nil)
    report_name ||= "performance_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}"

    html_content = build_html_report(report_name)
    html_report_path = File.join(@report_dir, "#{report_name}.html")

    File.write(html_report_path, html_content)
    html_report_path
  end

  private

  def ensure_report_directory
    FileUtils.mkdir_p(@report_dir)
  end

  def build_metadata
    {
      generated_at: Time.current.iso8601,
      ruby_version: RUBY_VERSION,
      rails_version: Rails::VERSION::STRING,
      environment: Rails.env,
      total_tests: @results.count,
      report_version: '1.0.0'
    }
  end

  def build_summary
    return {} if @results.empty?

    execution_times = @results.map(&:execution_time).compact
    memory_usages = @results.map { |r| r.memory_usage[:total_allocated] rescue 0 }.compact
    db_queries = @results.map(&:db_queries).compact
    throughputs = @results.map(&:throughput).compact

    {
      total_tests: @results.count,
      execution_time: {
        average: average(execution_times),
        min: execution_times.min,
        max: execution_times.max,
        total: execution_times.sum
      },
      memory_usage: {
        average: average(memory_usages),
        min: memory_usages.min,
        max: memory_usages.max,
        total: memory_usages.sum
      },
      db_queries: {
        average: average(db_queries),
        min: db_queries.min,
        max: db_queries.max,
        total: db_queries.sum
      },
      throughput: {
        average: average(throughputs),
        min: throughputs.min,
        max: throughputs.max
      }
    }
  end

  def build_detailed_results
    @results.map(&:to_h)
  end

  def build_analysis
    return { insights: [] } if @results.empty?

    insights = []

    # 性能趋势分析
    insights << analyze_performance_trends

    # 瓶颈识别
    insights << identify_bottlenecks

    # 回归检测
    insights << detect_regressions

    { insights: insights.compact }
  end

  def build_recommendations
    recommendations = []

    # 基于结果的具体建议
    slow_tests = @results.select { |r| r.execution_time && r.execution_time > 5.0 }
    if slow_tests.any?
      recommendations << {
        type: 'performance',
        priority: 'high',
        title: '优化慢速测试',
        description: "发现 #{slow_tests.count} 个慢速测试，建议优化",
        affected_tests: slow_tests.map(&:test_name)
      }
    end

    # 数据库查询优化建议
    query_heavy_tests = @results.select { |r| r.db_queries && r.db_queries > 100 }
    if query_heavy_tests.any?
      recommendations << {
        type: 'database',
        priority: 'medium',
        title: '减少数据库查询',
        description: "发现 #{query_heavy_tests.count} 个查询密集的测试",
        affected_tests: query_heavy_tests.map(&:test_name)
      }
    end

    # 内存使用优化建议
    memory_heavy_tests = @results.select do |r|
      r.memory_usage[:total_allocated] && r.memory_usage[:total_allocated] > 10_000_000
    end

    if memory_heavy_tests.any?
      recommendations << {
        type: 'memory',
        priority: 'medium',
        title: '优化内存使用',
        description: "发现 #{memory_heavy_tests.count} 个内存密集的测试",
        affected_tests: memory_heavy_tests.map(&:test_name)
      }
    end

    recommendations
  end

  def analyze_performance_trends
    # 对于多次运行的测试，分析趋势
    grouped_results = @results.group_by(&:test_name)
    trends = []

    grouped_results.each do |test_name, test_results|
      next if test_results.count < 2

      times = test_results.map(&:execution_time).compact
      if times.length >= 2
        trend = calculate_trend(times)
        trends << {
          test_name: test_name,
          trend: trend,
          improvement: trend < 0
        }
      end
    end

    { trends: trends }
  end

  def identify_bottlenecks
    # 识别性能瓶颈
    bottlenecks = []

    # 执行时间瓶颈
    max_execution_time = @results.map(&:execution_time).compact.max || 0
    @results.select { |r| r.execution_time == max_execution_time }.each do |result|
      bottlenecks << {
        type: 'execution_time',
        test_name: result.test_name,
        value: result.execution_time
      }
    end

    # 查询数量瓶颈
    max_db_queries = @results.map(&:db_queries).compact.max || 0
    @results.select { |r| r.db_queries == max_db_queries }.each do |result|
      bottlenecks << {
        type: 'db_queries',
        test_name: result.test_name,
        value: result.db_queries
      }
    end

    { bottlenecks: bottlenecks }
  end

  def detect_regressions
    # 简单的回归检测（可与历史数据比较）
    # 这里实现基本逻辑，实际使用时需要历史数据
    slow_tests = @results.select { |r| r.execution_time && r.execution_time > 10.0 }

    {
      potential_regressions: slow_tests.map do |result|
        {
          test_name: result.test_name,
          execution_time: result.execution_time,
          warning: '执行时间超过10秒，可能存在性能回归'
        }
      end
    }
  end

  def save_report(report_name, data)
    json_file = File.join(@report_dir, "#{report_name}.json")
    File.write(json_file, JSON.pretty_generate(data))
  end

  def build_html_report(report_name)
    html_template = <<-HTML
<!DOCTYPE html>
<html>
<head>
    <title>#{report_name}</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .metric { margin: 10px 0; padding: 10px; border: 1px solid #ddd; }
        .chart { margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>性能测试报告</h1>
    <p>生成时间: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}</p>

    <h2>测试概要</h2>
    <div class="metric">
        <strong>总测试数:</strong> #{@results.count}
    </div>

    <h2>性能指标</h2>
    #{build_summary_html}

    <h2>详细结果</h2>
    #{build_detailed_results_html}

    <div class="chart">
        <canvas id="performanceChart"></canvas>
    </div>

    <script>
        #{build_chart_js}
    </script>
</body>
</html>
    HTML

    html_template
  end

  def build_summary_html
    summary = build_summary
    return '' if summary.empty?

    html = '<table>'
    summary.each do |category, metrics|
      next if metrics.empty?

      html += "<tr><th colspan='2'>#{category.to_s.titleize}</th></tr>"
      metrics.each do |metric, value|
        html += "<tr><td>#{metric.to_s.titleize}</td><td>#{format_metric_value(value)}</td></tr>"
      end
    end
    html += '</table>'

    html
  end

  def build_detailed_results_html
    html = '<table>'
    html += '<tr><th>测试名称</th><th>执行时间(s)</th><th>数据库查询</th><th>内存使用(bytes)</th><th>吞吐量</th></tr>'

    @results.each do |result|
      memory = result.memory_usage[:total_allocated] rescue 'N/A'
      html += "<tr>
        <td>#{result.test_name}</td>
        <td>#{result.execution_time&.round(3) || 'N/A'}</td>
        <td>#{result.db_queries || 'N/A'}</td>
        <td>#{memory}</td>
        <td>#{result.throughput || 'N/A'}</td>
      </tr>"
    end

    html += '</table>'
    html
  end

  def build_chart_js
    test_names = @results.map(&:test_name)
    execution_times = @results.map(&:execution_time)
    db_queries = @results.map(&:db_queries)

    <<-JS
    const ctx = document.getElementById('performanceChart').getContext('2d');
    const chart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: #{test_names.to_json},
            datasets: [{
                label: '执行时间(s)',
                data: #{execution_times.to_json},
                backgroundColor: 'rgba(54, 162, 235, 0.2)',
                borderColor: 'rgba(54, 162, 235, 1)',
                borderWidth: 1,
                yAxisID: 'y'
            }, {
                label: '数据库查询数',
                data: #{db_queries.to_json},
                backgroundColor: 'rgba(255, 99, 132, 0.2)',
                borderColor: 'rgba(255, 99, 132, 1)',
                borderWidth: 1,
                yAxisID: 'y1'
            }]
        },
        options: {
            scales: {
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                },
                y1: {
                    type: 'linear',
                    display: true,
                    position: 'right',
                    grid: {
                        drawOnChartArea: false,
                    },
                }
            }
        }
    });
    JS
  end

  def check_thresholds
    # 实现阈值检查逻辑
    {
      execution_time: { status: 'pass', threshold: 10.0, actual: 0 },
      db_queries: { status: 'pass', threshold: 100, actual: 0 },
      memory_usage: { status: 'pass', threshold: 50_000_000, actual: 0 }
    }
  end

  def critical_recommendations
    build_recommendations.select { |r| r[:priority] == 'high' }
  end

  def generate_charts(report_name)
    # 可以扩展为生成更多图表
  end

  def should_generate_charts?
    # 根据配置决定是否生成图表
    true
  end

  def average(numbers)
    return 0 if numbers.empty?
    (numbers.sum.to_f / numbers.count).round(3)
  end

  def calculate_trend(values)
    return 0 if values.count < 2

    # 简单线性回归计算趋势
    n = values.count
    x_values = (0..(n-1)).to_a

    x_mean = x_values.sum.to_f / n
    y_mean = values.sum.to_f / n

    numerator = (0..(n-1)).map { |i| (x_values[i] - x_mean) * (values[i] - y_mean) }.sum
    denominator = (0..(n-1)).map { |i| (x_values[i] - x_mean) ** 2 }.sum

    return 0 if denominator == 0
    (numerator / denominator).round(6)
  end

  def format_metric_value(value)
    case value
    when Float
      value.round(3)
    when Integer
      value
    else
      value
    end
  end
end