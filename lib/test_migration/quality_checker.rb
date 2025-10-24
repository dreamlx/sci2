# frozen_string_literal: true

module TestMigration
  # Quality checker for migrated tests
  class QualityChecker
    QUALITY_STANDARDS = {
      service: {
        required_methods: %w[call],
        required_patterns: %w[describe.*call context.*valid context.*invalid],
        recommended_patterns: %w[context.*unexpected error let.*service],
        forbidden_patterns: %w[visit get post put delete],
        min_assertions: 3
      },
      command: {
        required_methods: %w[call],
        required_patterns: %w[describe.*call context.*valid context.*invalid],
        recommended_patterns: %w[ActiveModel validations subject.*result\.success],
        forbidden_patterns: %w[visit get post put delete],
        min_assertions: 4
      },
      policy: {
        required_methods: %w[can_index\? can_show\? can_create\? can_update\? can_destroy\?],
        required_patterns: %w[context.*super admin context.*regular admin context.*user.*nil],
        recommended_patterns: %w[authorization_error_message role_display_name],
        forbidden_patterns: %w[visit get post put delete create update destroy],
        min_assertions: 5
      },
      repository: {
        required_methods: %w[find find_by_id],
        required_patterns: %w[describe\.find describe\.by_status],
        recommended_patterns: %w[safe_find exists\? created_between page],
        forbidden_patterns: %w[visit get post put delete],
        min_assertions: 6
      }
    }.freeze

    def initialize
      @issues = []
      @recommendations = []
      @scores = {}
    end

    def check_file(file_path, pattern_type = nil)
      return { error: "File not found: #{file_path}" } unless File.exist?(file_path)

      content = File.read(file_path)
      detected_type = pattern_type || detect_pattern_type(file_path)

      check_result = {
        file_path: file_path,
        pattern_type: detected_type,
        content_analysis: analyze_content(content),
        quality_score: 0,
        issues: [],
        recommendations: [],
        passed_checks: 0,
        total_checks: 0
      }

      if detected_type && QUALITY_STANDARDS.key?(detected_type)
        check_against_standards(content, detected_type, check_result)
      else
        check_result[:issues] << "Unknown or unsupported pattern type: #{detected_type}"
      end

      check_result[:quality_score] = calculate_overall_score(check_result)

      check_result
    end

    def check_directory(directory, pattern_type = nil)
      results = []

      Dir.glob("#{directory}/**/*_spec.rb").each do |file|
        next if file.include?('support/') || file.include?('helpers/')

        result = check_file(file, pattern_type)
        results << result unless result[:error]
      end

      generate_directory_summary(results)
    end

    def validate_migration(original_file, migrated_file)
      original_check = check_file(original_file)
      migrated_check = check_file(migrated_file)

      validation = {
        original_file: original_file,
        migrated_file: migrated_file,
        migration_quality: 0,
        completeness_check: check_completeness(original_check, migrated_check),
        improvement_check: check_improvements(original_check, migrated_check),
        regression_check: check_regressions(original_check, migrated_check),
        overall_assessment: 'unknown'
      }

      validation[:migration_quality] = calculate_migration_quality(validation)
      validation[:overall_assessment] = determine_assessment(validation)

      validation
    end

    def generate_quality_report(directory = 'spec')
      puts "🔍 Generating quality report for #{directory}..."

      results = check_directory(directory)

      {
        summary: generate_report_summary(results),
        by_pattern_type: group_results_by_type(results),
        common_issues: extract_common_issues(results),
        recommendations: generate_overall_recommendations(results),
        detailed_results: results
      }
    end

    private

    def detect_pattern_type(file_path)
      case file_path
      when %r{spec/services/}
        :service
      when %r{spec/commands/}
        :command
      when %r{spec/policies/}
        :policy
      when %r{spec/repositories/}
        :repository
      end
    end

    def analyze_content(content)
      {
        lines_count: content.lines.count,
        characters_count: content.length,
        describe_blocks: content.scan(/describe\s+['"]/).length,
        context_blocks: content.scan(/context\s+['"]/).length,
        it_blocks: content.scan(/it\s+['"]/).length,
        let_definitions: content.scan(/let\s+:/).length,
        expectations: content.scan('expect(').length,
        factories: content.scan('create(').length,
        mocks: content.scan('allow(').length
      }
    end

    def check_against_standards(content, pattern_type, check_result)
      standards = QUALITY_STANDARDS[pattern_type]

      # Check required methods
      check_required_methods(content, standards[:required_methods], check_result)

      # Check required patterns
      check_patterns(content, standards[:required_patterns], :required, check_result)

      # Check recommended patterns
      check_patterns(content, standards[:recommended_patterns], :recommended, check_result)

      # Check forbidden patterns
      check_forbidden_patterns(content, standards[:forbidden_patterns], check_result)

      # Check minimum assertions
      check_minimum_assertions(content, standards[:min_assertions], check_result)

      # Check structure quality
      check_structure_quality(content, check_result)
    end

    def check_required_methods(content, required_methods, check_result)
      required_methods.each do |method|
        if content.include?(method)
          check_result[:passed_checks] += 1
        else
          check_result[:issues] << "Missing required method: #{method}"
        end
        check_result[:total_checks] += 1
      end
    end

    def check_patterns(content, patterns, type, check_result)
      patterns.each do |pattern|
        regex = Regexp.new(pattern, Regexp::IGNORECASE)
        if content.match?(regex)
          check_result[:passed_checks] += 1
        else
          message = "#{type == :required ? 'Missing' : 'Consider adding'} pattern: #{pattern}"
          if type == :required
            check_result[:issues] << message
          else
            check_result[:recommendations] << message
          end
        end
        check_result[:total_checks] += 1
      end
    end

    def check_forbidden_patterns(content, forbidden_patterns, check_result)
      forbidden_patterns.each do |pattern|
        regex = Regexp.new(pattern, Regexp::IGNORECASE)
        if content.match?(regex)
          check_result[:issues] << "Found forbidden pattern: #{pattern}"
        else
          check_result[:passed_checks] += 1
        end
        check_result[:total_checks] += 1
      end
    end

    def check_minimum_assertions(content, min_assertions, check_result)
      actual_assertions = content.scan('expect(').length
      check_result[:total_checks] += 1

      if actual_assertions >= min_assertions
        check_result[:passed_checks] += 1
      else
        check_result[:issues] << "Insufficient assertions: #{actual_assertions} (minimum: #{min_assertions})"
      end
    end

    def check_structure_quality(_content, check_result)
      analysis = check_result[:content_analysis]

      # Check for proper structure
      if analysis[:describe_blocks] > 0
        check_result[:passed_checks] += 1
      else
        check_result[:issues] << 'Missing describe blocks'
      end
      check_result[:total_checks] += 1

      # Check for context organization (recommended but not required)
      if analysis[:context_blocks] > 0
        check_result[:passed_checks] += 1
      else
        check_result[:recommendations] << 'Consider using context blocks for better organization'
      end
      check_result[:total_checks] += 1

      # Check for proper variable usage with let
      if analysis[:let_definitions] > 0
        check_result[:passed_checks] += 1
      else
        check_result[:recommendations] << 'Consider using let for test data setup'
      end
      check_result[:total_checks] += 1
    end

    def calculate_overall_score(check_result)
      return 0 if check_result[:total_checks] == 0

      base_score = (check_result[:passed_checks].to_f / check_result[:total_checks] * 100).round

      # Apply penalties for issues
      issue_penalty = check_result[:issues].length * 10

      # Apply small bonuses for recommendations being followed
      recommendation_bonus = check_result[:recommendations].empty? ? 5 : 0

      [0, [100, base_score - issue_penalty + recommendation_bonus].min].max
    end

    def check_completeness(original_check, migrated_check)
      return { score: 0, issues: ['Original file could not be analyzed'] } if original_check[:error]
      return { score: 0, issues: ['Migrated file could not be analyzed'] } if migrated_check[:error]

      original_tests = original_check[:content_analysis][:it_blocks]
      migrated_tests = migrated_check[:content_analysis][:it_blocks]

      score = if original_tests == 0
                migrated_tests > 0 ? 100 : 0
              else
                [100, (migrated_tests.to_f / original_tests * 100).round].min
              end

      issues = []
      issues << "Test coverage reduced from #{original_tests} to #{migrated_tests} test cases" if score < 80

      { score: score, issues: issues }
    end

    def check_improvements(original_check, migrated_check)
      improvements = []

      original_quality = original_check[:quality_score] || 0
      migrated_quality = migrated_check[:quality_score] || 0

      if migrated_quality > original_quality
        improvements << "Quality improved from #{original_quality} to #{migrated_quality}"
      elsif migrated_quality < original_quality
        improvements << "Quality decreased from #{original_quality} to #{migrated_quality}"
      end

      # Check for structure improvements
      if migrated_check[:content_analysis][:context_blocks] > original_check[:content_analysis][:context_blocks]
        improvements << 'Better organization with context blocks'
      end

      if migrated_check[:content_analysis][:let_definitions] > original_check[:content_analysis][:let_definitions]
        improvements << 'Better test data management with let'
      end

      improvements
    end

    def check_regressions(original_check, migrated_check)
      regressions = []

      # Check for lost functionality
      if !original_check[:error] && !migrated_check[:error]
        original_patterns = original_check[:content_analysis]
        migrated_patterns = migrated_check[:content_analysis]

        if original_patterns[:it_blocks] > migrated_patterns[:it_blocks]
          regressions << "Lost test cases: #{original_patterns[:it_blocks] - migrated_patterns[:it_blocks]}"
        end

        if original_patterns[:describe_blocks] > migrated_patterns[:describe_blocks]
          regressions << "Lost describe blocks: #{original_patterns[:describe_blocks] - migrated_patterns[:describe_blocks]}"
        end
      end

      regressions
    end

    def calculate_migration_quality(validation)
      completeness_score = validation[:completeness_check][:score]
      base_quality = validation[:migrated_check][:quality_score] || 0
      improvements_count = validation[:improvement_check].length
      regressions_count = validation[:regression_check].length

      # Weighted calculation
      quality_score = ((completeness_score * 0.4) + (base_quality * 0.4)).round
      improvement_bonus = improvements_count * 5
      regression_penalty = regressions_count * 15

      [0, [100, quality_score + improvement_bonus - regression_penalty].min].max
    end

    def determine_assessment(validation)
      quality = validation[:migration_quality]
      regressions = validation[:regression_check].length

      if quality >= 90 && regressions == 0
        'excellent'
      elsif quality >= 75 && regressions == 0
        'good'
      elsif quality >= 60
        'acceptable'
      elsif quality >= 40
        'needs_improvement'
      else
        'poor'
      end
    end

    def generate_directory_summary(results)
      return { error: 'No results to summarize' } if results.empty?

      total_files = results.length
      average_quality = (results.sum { |r| r[:quality_score] } / total_files.to_f).round(1)
      total_issues = results.sum { |r| r[:issues].length }
      total_recommendations = results.sum { |r| r[:recommendations].length }

      quality_distribution = results.group_by { |r| r[:quality_score] / 10 * 10 }
                                    .transform_values(&:length)

      {
        total_files: total_files,
        average_quality: average_quality,
        total_issues: total_issues,
        total_recommendations: total_recommendations,
        quality_distribution: quality_distribution,
        files_with_issues: results.count { |r| r[:issues].any? },
        files_perfect: results.count { |r| r[:quality_score] >= 90 }
      }
    end

    def group_results_by_type(results)
      results.group_by { |r| r[:pattern_type] }
             .transform_values do |type_results|
        {
          count: type_results.length,
          average_quality: (type_results.sum { |r| r[:quality_score] } / type_results.length.to_f).round(1),
          common_issues: extract_common_issues(type_results)
        }
      end
    end

    def extract_common_issues(results)
      issue_counts = Hash.new(0)

      results.each do |result|
        result[:issues].each do |issue|
          issue_counts[issue] += 1
        end
      end

      issue_counts.sort_by { |_, count| -count }.first(5).to_h
    end

    def generate_overall_recommendations(results)
      all_recommendations = results.flat_map { |r| r[:recommendations] }
      recommendation_counts = Hash.new(0)

      all_recommendations.each do |rec|
        recommendation_counts[rec] += 1
      end

      # Get top recommendations that appear in multiple files
      recommendation_counts
        .select { |_, count| count >= 2 }
        .sort_by { |_, count| -count }
        .first(10)
        .map { |rec, count| { recommendation: rec, frequency: count } }
    end
  end
end
