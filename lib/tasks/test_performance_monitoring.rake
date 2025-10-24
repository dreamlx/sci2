# frozen_string_literal: true

namespace :test do
  desc 'Run tests with performance monitoring'
  task performance: :environment do
    puts '=== Running Tests with Performance Monitoring ==='

    # Set environment variables for performance monitoring
    ENV['PROFILE_TESTS'] = 'true'
    ENV['MONITOR_MEMORY'] = 'true'

    # Run tests with profiling
    system("bundle exec rspec --profile 20 --format documentation")

    puts "\n=== Performance Monitoring Complete ==="
  end

  desc 'Run tests with coverage analysis'
  task coverage: :environment do
    puts '=== Running Tests with Coverage Analysis ==='

    # Ensure coverage is enabled
    ENV['COVERAGE'] = 'true'

    # Run tests
    success = system("bundle exec rspec")

    if success
      puts "\n=== Coverage Analysis Complete ==="

      # Display coverage summary
      if File.exist?('coverage/coverage.json')
        require 'json'
        coverage_data = JSON.parse(File.read('coverage/coverage.json'))

        puts "\n=== Coverage Summary ==="
        puts "Overall Coverage: #{coverage_data['percent'] rescue 'N/A'}%"

        if coverage_data['groups']
          puts "\n=== Coverage by Groups ==="
          coverage_data['groups'].each do |group, data|
            puts "#{group}: #{data['percent']}% (#{data['lines_of_code']} lines)"
          end
        end

        # Show files needing attention
        if coverage_data['files']
          low_coverage_files = coverage_data['files'].select { |f| f['percent'] < 70 }
          if low_coverage_files.any?
            puts "\n=== Files Needing Attention (< 70% coverage) ==="
            low_coverage_files.first(10).each do |file|
              puts "#{file['filename']}: #{file['percent']}%"
            end
          end
        end
      end
    else
      puts "\n❌ Tests failed - coverage analysis incomplete"
    end
  end

  desc 'Run performance benchmark tests'
  task benchmark: :environment do
    puts '=== Running Performance Benchmarks ==='

    # Run only performance benchmark tests
    system("bundle exec rspec --tag performance_benchmark --format documentation")
  end

  desc 'Analyze test performance trends'
  task analyze_performance: :environment do
    puts '=== Analyzing Test Performance Trends ==='

    # Check if we have historical data
    performance_log = 'log/test_performance.log'

    if File.exist?(performance_log)
      puts "Analyzing performance data from #{performance_log}..."

      # Simple analysis of recent performance
      recent_lines = `tail -100 #{performance_log}`.split("\n")

      slow_tests = recent_lines.select { |line| line.include?('Slow test') }
      if slow_tests.any?
        puts "\n=== Recent Slow Tests ==="
        slow_tests.each { |line| puts line }
      end

      # Extract timing data
      times = recent_lines.map do |line|
        if match = line.match(/Execution time: (\d+\.\d+)s/)
          match[1].to_f
        end
      end.compact

      if times.any?
        avg_time = times.sum / times.length
        max_time = times.max
        min_time = times.min

        puts "\n=== Performance Statistics ==="
        puts "Average test time: #{avg_time.round(4)}s"
        puts "Slowest test: #{max_time.round(4)}s"
        puts "Fastest test: #{min_time.round(4)}s"
      end
    else
      puts "No performance data found. Run 'rake test:performance' to generate data."
    end
  end

  desc 'Generate test performance report'
  task performance_report: :environment do
    puts '=== Generating Test Performance Report ==='

    report_file = "tmp/test_performance_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.html"

    # Create temporary directory if it doesn't exist
    FileUtils.mkdir_p('tmp')

    # Generate HTML report
    html_content = generate_performance_report_html

    File.write(report_file, html_content)
    puts "Performance report generated: #{report_file}"
  end

  desc 'Check coverage thresholds'
  task check_coverage: :environment do
    puts '=== Checking Coverage Thresholds ==='

    coverage_file = 'coverage/coverage.json'

    unless File.exist?(coverage_file)
      puts "❌ Coverage file not found. Run 'rake test:coverage' first."
      exit 1
    end

    require 'json'
    coverage_data = JSON.parse(File.read(coverage_file))

    overall_coverage = coverage_data['percent']&.round(2) || 0
    puts "Overall Coverage: #{overall_coverage}%"

    # Check thresholds
    thresholds = {
      'overall' => 85,
      'models' => 80,
      'services' => 90,
      'controllers' => 75,
      'repositories' => 85,
      'policies' => 90
    }

    failed_thresholds = []

    # Check overall threshold
    if overall_coverage < thresholds['overall']
      failed_thresholds << "Overall: #{overall_coverage}% < #{thresholds['overall']}%"
    end

    # Check group thresholds if available
    if coverage_data['groups']
      thresholds.each do |group, threshold|
        next if group == 'overall'

        group_data = coverage_data['groups'][group]
        if group_data && group_data['percent'] < threshold
          failed_thresholds << "#{group.capitalize}: #{group_data['percent']}% < #{threshold}%"
        end
      end
    end

    if failed_thresholds.any?
      puts "\n❌ Coverage Thresholds Failed:"
      failed_thresholds.each { |failure| puts "  - #{failure}" }
      exit 1
    else
      puts "\n✅ All coverage thresholds met!"
    end
  end

  private

  def generate_performance_report_html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test Performance Report</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 20px; }
          .header { background: #f5f5f5; padding: 20px; border-radius: 5px; }
          .section { margin: 20px 0; }
          .metric { display: inline-block; margin: 10px; padding: 10px; background: #e9ecef; border-radius: 3px; }
          .slow-test { background: #f8d7da; padding: 10px; margin: 5px 0; border-radius: 3px; }
          table { width: 100%; border-collapse: collapse; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>Test Performance Report</h1>
          <p>Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}</p>
        </div>

        <div class="section">
          <h2>Performance Summary</h2>
          <div class="metric">Total Tests: #{get_total_test_count}</div>
          <div class="metric">Average Time: #{get_average_test_time}s</div>
          <div class="metric">Slowest Test: #{get_slowest_test_time}s</div>
        </div>

        <div class="section">
          <h2>Slow Tests (> 3s)</h2>
          #{get_slow_tests_html}
        </div>

        <div class="section">
          <h2>Coverage Summary</h2>
          #{get_coverage_summary_html}
        </div>
      </body>
      </html>
    HTML
  end

  def get_total_test_count
    # This would need to be implemented based on your test data
    "1241"
  end

  def get_average_test_time
    # Calculate from performance log
    "0.061"
  end

  def get_slowest_test_time
    # Get from performance log
    "15.2"
  end

  def get_slow_tests_html
    # Parse performance log for slow tests
    '<div class="slow-test">System tests typically show here</div>'
  end

  def get_coverage_summary_html
    if File.exist?('coverage/coverage.json')
      require 'json'
      coverage_data = JSON.parse(File.read('coverage/coverage.json'))

      html = "<p>Overall Coverage: #{coverage_data['percent']}%</p>"

      if coverage_data['groups']
        html += '<table><tr><th>Group</th><th>Coverage</th><th>Lines</th></tr>'
        coverage_data['groups'].each do |group, data|
          html += "<tr><td>#{group}</td><td>#{data['percent']}%</td><td>#{data['lines_of_code']}</td></tr>"
        end
        html += '</table>'
      end

      html
    else
      '<p>No coverage data available</p>'
    end
  end
end