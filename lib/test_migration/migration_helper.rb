# frozen_string_literal: true

module TestMigration
  # Helper class for analyzing and migrating existing tests
  class MigrationHelper
    LEGACY_PATTERNS = {
      controller: %r{spec/controllers/.*_controller_spec\.rb},
      model: %r{spec/models/.*_spec\.rb},
      request: %r{spec/requests/.*_spec\.rb},
      feature: %r{spec/features/.*_spec\.rb},
      system: %r{spec/system/.*_spec\.rb}
    }.freeze

    NEW_ARCHITECTURE_PATTERNS = {
      service: %r{spec/services/.*_spec\.rb},
      command: %r{spec/commands/.*_spec\.rb},
      policy: %r{spec/policies/.*_spec\.rb},
      repository: %r{spec/repositories/.*_spec\.rb}
    }.freeze

    def initialize
      @legacy_tests = []
      @new_architecture_tests = []
      @migration_suggestions = {}
    end

    def analyze_all_tests
      puts "🔍 Analyzing test files..."

      find_legacy_tests
      find_new_architecture_tests
      generate_migration_suggestions

      {
        legacy_tests: @legacy_tests,
        new_architecture_tests: @new_architecture_tests,
        migration_suggestions: @migration_suggestions,
        statistics: generate_statistics
      }
    end

    def analyze_file(file_path)
      return { error: "File not found: #{file_path}" } unless File.exist?(file_path)

      content = File.read(file_path)
      analysis = {
        file_path: file_path,
        size: content.size,
        lines: content.lines.count,
        type: detect_test_type(file_path),
        patterns: extract_patterns(content),
        complexity: assess_complexity(content),
        migration_candidates: suggest_migration_targets_for_file(content, file_path)
      }

      analysis
    end

    def suggest_migration(file_path)
      analysis = analyze_file(file_path)
      return analysis if analysis[:error]

      suggestions = []

      analysis[:migration_candidates].each do |candidate|
        suggestions << generate_migration_suggestion(analysis, candidate)
      end

      {
        file: file_path,
        current_type: analysis[:type],
        suggestions: suggestions,
        effort_estimate: estimate_migration_effort(analysis)
      }
    end

    def generate_template_for_migration(file_path, target_pattern)
      analysis = analyze_file(file_path)
      return { error: "Cannot analyze file: #{file_path}" } if analysis[:error]

      class_name = extract_class_name(file_path)
      generator = TestMigration::TemplateGenerator.new(target_pattern, class_name)

      template = generator.generate
      template[:migration_notes] = generate_migration_notes(analysis, target_pattern)

      template
    end

    def validate_migration(original_file, migrated_file)
      original_analysis = analyze_file(original_file)
      migrated_analysis = analyze_file(migrated_file)

      validation = {
        completeness_score: calculate_completeness_score(original_analysis, migrated_analysis),
        quality_score: calculate_quality_score(migrated_analysis),
        missing_tests: identify_missing_tests(original_analysis, migrated_analysis),
        recommendations: generate_validation_recommendations(original_analysis, migrated_analysis)
      }

      validation
    end

    private

    def find_legacy_tests
      Dir.glob('spec/**/*_spec.rb').each do |file|
        next if file.include?('support/') || file.include?('helpers/')

        path = Pathname.new(file)

        LEGACY_PATTERNS.each do |type, pattern|
          if file.match?(pattern)
            @legacy_tests << {
              path: file,
              type: type,
              relative_path: path.relative_path_from(Pathname.new('spec')).to_s
            }
            break
          end
        end
      end

      puts "  Found #{@legacy_tests.length} legacy test files"
    end

    def find_new_architecture_tests
      Dir.glob('spec/**/*_spec.rb').each do |file|
        NEW_ARCHITECTURE_PATTERNS.each do |type, pattern|
          if file.match?(pattern)
            @new_architecture_tests << {
              path: file,
              type: type,
              relative_path: Pathname.new(file).relative_path_from(Pathname.new('spec')).to_s
            }
            break
          end
        end
      end

      puts "  Found #{@new_architecture_tests.length} new architecture test files"
    end

    def generate_migration_suggestions
      puts "💡 Generating migration suggestions..."

      @legacy_tests.each do |test|
        suggestions = []

        case test[:type]
        when :controller
          suggestions += suggest_controller_migration(test)
        when :model
          suggestions += suggest_model_migration(test)
        when :request
          suggestions += suggest_request_migration(test)
        when :feature, :system
          suggestions += suggest_integration_migration(test)
        end

        @migration_suggestions[test[:path]] = suggestions if suggestions.any?
      end

      puts "  Generated suggestions for #{@migration_suggestions.keys.length} files"
    end

    def suggest_controller_migration(test)
      content = File.read(test[:path])
      suggestions = []

      if content.include?('create') || content.include?('update') || content.include?('destroy')
        suggestions << { target: :command, priority: 'high', reason: 'Controller actions with state changes should become Commands' }
      end

      if content.include?('authorize') || content.include?('can?')
        suggestions << { target: :policy, priority: 'high', reason: 'Authorization logic should be extracted to Policies' }
      end

      if content.include?('Service') || content.include?('complex business logic')
        suggestions << { target: :service, priority: 'medium', reason: 'Complex business logic should be extracted to Services' }
      end

      suggestions
    end

    def suggest_model_migration(test)
      content = File.read(test[:path])
      suggestions = []

      if content.include?('scope') || content.include?('where') || content.include?('find_by')
        suggestions << { target: :repository, priority: 'medium', reason: 'Complex queries should be moved to Repositories' }
      end

      if content.include?('def calculate') || content.include?('business logic')
        suggestions << { target: :service, priority: 'high', reason: 'Business logic should be extracted to Services' }
      end

      suggestions
    end

    def suggest_request_migration(test)
      content = File.read(test[:path])
      suggestions = []

      if content.include?('POST') || content.include?('PUT') || content.include?('DELETE')
        suggestions << { target: :command, priority: 'high', reason: 'State-changing requests should test Commands directly' }
      end

      suggestions
    end

    def suggest_integration_migration(test)
      content = File.read(test[:path])
      suggestions = []

      if content.include?('fill_in') || content.include?('click_on')
        suggestions << { target: :service, priority: 'medium', reason: 'Complex workflows can be tested at Service level' }
      end

      suggestions
    end

    def detect_test_type(file_path)
      LEGACY_PATTERNS.each { |type, pattern| return type if file_path.match?(pattern) }
      NEW_ARCHITECTURE_PATTERNS.each { |type, pattern| return type if file_path.match?(pattern) }
      'unknown'
    end

    def extract_patterns(content)
      patterns = {
        has_describe_blocks: content.scan(/describe\s+['"]/).any?,
        has_context_blocks: content.scan(/context\s+['"]/).any?,
        has_it_blocks: content.scan(/it\s+['"]/).any?,
        has_let_definitions: content.scan(/let\s+[:]/).any?,
        has_expectations: content.scan(/expect\(/).any?,
        has_factories: content.scan(/create\(/).any?,
        has_mocks: content.scan(/allow\(/).any?,
        has_database_transactions: content.include?('transactional fixtures')
      }

      patterns
    end

    def assess_complexity(content)
      score = 0

      # Count different complexity indicators
      score += content.scan(/describe\s+['"]/).length * 1
      score += content.scan(/context\s+['"]/).length * 2
      score += content.scan(/it\s+['"]/).length * 1
      score += content.scan(/let\s+[:]/).length * 0.5
      score += content.scan(/allow\(/).length * 2
      score += content.scan(/expect\(/).length * 0.5

      # Normalize to 1-10 scale
      [1, [10, (score / 10).ceil].min].max
    end

    def suggest_migration_targets_for_file(content, file_path)
      candidates = []

      # Analyze content to suggest migration targets
      if content.include?('Service') || content.include?('business logic') || content.include?('calculate')
        candidates << { target: :service, reason: 'Contains business logic' }
      end

      if content.include?('create') || content.include?('update') || content.include?('destroy') || content.include?('call')
        candidates << { target: :command, reason: 'Contains state-changing operations' }
      end

      if content.include?('can?') || content.include?('authorize') || content.include?('policy')
        candidates << { target: :policy, reason: 'Contains authorization logic' }
      end

      if content.include?('find') || content.include?('where') || content.include?('scope') || content.include?('repository')
        candidates << { target: :repository, reason: 'Contains data access logic' }
      end

      candidates
    end

    def estimate_migration_effort(analysis)
      complexity = analysis[:complexity]
      migration_candidates = analysis[:migration_candidates].length

      base_effort = case complexity
                   when 1..3 then 'low'
                   when 4..7 then 'medium'
                   else 'high'
                   end

      "#{base_effort} (#{migration_candidates} potential targets)"
    end

    def extract_class_name(file_path)
      basename = File.basename(file_path, '_spec.rb')
      basename.camelize
    end

    def generate_migration_notes(analysis, target_pattern)
      [
        "# Migration Notes:",
        "# Original file: #{analysis[:file_path]}",
        "# Original type: #{analysis[:type]}",
        "# Target pattern: #{target_pattern}",
        "# Complexity: #{analysis[:complexity]}/10",
        "#",
        "# TODO: Customize test data and assertions",
        "# TODO: Replace **YOUR_MODEL** placeholders",
        "# TODO: Add specific assertions for your business logic"
      ]
    end

    def calculate_completeness_score(original, migrated)
      return 0 if original[:error] || migrated[:error]

      original_tests = original[:patterns][:has_it_blocks] ? 1 : 0
      migrated_tests = migrated[:patterns][:has_it_blocks] ? 1 : 0

      [0, [100, (migrated_tests.to_f / [original_tests, 1].max * 100).round].min].max
    end

    def calculate_quality_score(analysis)
      return 0 if analysis[:error]

      score = 0
      patterns = analysis[:patterns]

      score += 20 if patterns[:has_describe_blocks]
      score += 20 if patterns[:has_context_blocks]
      score += 20 if patterns[:has_it_blocks]
      score += 10 if patterns[:has_let_definitions]
      score += 20 if patterns[:has_expectations]
      score += 10 if patterns[:has_factories]

      score
    end

    def identify_missing_tests(original, migrated)
      return [] if original[:error] || migrated[:error]

      missing = []

      if original[:patterns][:has_describe_blocks] && !migrated[:patterns][:has_describe_blocks]
        missing << 'describe blocks'
      end

      if original[:patterns][:has_context_blocks] && !migrated[:patterns][:has_context_blocks]
        missing << 'context blocks'
      end

      missing
    end

    def generate_validation_recommendations(original, migrated)
      recommendations = []

      completeness = calculate_completeness_score(original, migrated)
      if completeness < 80
        recommendations << 'Add more test cases to achieve better coverage'
      end

      quality = calculate_quality_score(migrated)
      if quality < 70
        recommendations << 'Improve test structure with proper describe/context blocks'
      end

      if migrated[:complexity] > 7
        recommendations << 'Consider breaking down complex tests into smaller units'
      end

      recommendations
    end

    def generate_statistics
      legacy_by_type = @legacy_tests.group_by { |t| t[:type] }
      new_arch_by_type = @new_architecture_tests.group_by { |t| t[:type] }

      total_legacy = @legacy_tests.length
      total_new = @new_architecture_tests.length
      total_files = total_legacy + total_new

      {
        total_test_files: total_files,
        legacy_tests: total_legacy,
        new_architecture_tests: total_new,
        migration_progress: total_files > 0 ? (total_new.to_f / total_files * 100).round(1) : 0,
        legacy_by_type: legacy_by_type.transform_values(&:length),
        new_architecture_by_type: new_arch_by_type.transform_values(&:length),
        files_with_suggestions: @migration_suggestions.keys.length
      }
    end
  end
end