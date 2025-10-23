# frozen_string_literal: true

module TestMigration
  # Batch processor for handling large-scale test migrations
  class BatchProcessor
    def initialize(options = {})
      @options = {
        dry_run: options[:dry_run] || false,
        force_overwrite: options[:force_overwrite] || false,
        quality_threshold: options[:quality_threshold] || 70,
        batch_size: options[:batch_size] || 10,
        verbose: options[:verbose] || false
      }
      @migration_helper = MigrationHelper.new
      @quality_checker = QualityChecker.new
      @results = []
      @errors = []
    end

    def process_all_legacy_tests(target_patterns = nil)
      puts "🔄 Starting batch migration of legacy tests..."
      puts "📊 Dry run mode: #{@options[:dry_run] ? 'ENABLED' : 'DISABLED'}"

      analysis = @migration_helper.analyze_all_tests
      legacy_tests = analysis[:legacy_tests]

      if target_patterns
        legacy_tests = filter_by_target_patterns(legacy_tests, target_patterns)
      end

      puts "📋 Processing #{legacy_tests.length} legacy test files..."

      process_in_batches(legacy_tests) do |batch|
        process_batch(batch)
      end

      generate_batch_report
    end

    def generate_templates_for_patterns(patterns, class_names)
      puts "📝 Generating templates for patterns: #{patterns.join(', ')}"

      templates = []

      patterns.each do |pattern|
        class_names.each do |class_name|
          begin
            generator = TemplateGenerator.new(pattern, class_name)
            template = generator.generate

            unless @options[:dry_run]
              written = generator.write_to_file
              if written
                templates << template
                puts "  ✅ Generated #{pattern} template: #{class_name}"
              else
                puts "  ⚠️  Skipped existing file: #{template[:file_path]}"
              end
            else
              templates << template
              puts "  📄 Would generate: #{template[:file_path]}"
            end
          rescue => e
            @errors << {
              type: :template_generation,
              pattern: pattern,
              class_name: class_name,
              error: e.message
            }
            puts "  ❌ Error generating #{pattern} template for #{class_name}: #{e.message}"
          end
        end
      end

      templates
    end

    def validate_migrations(migration_pairs)
      puts "🔍 Validating migration quality..."

      validations = []

      migration_pairs.each do |original_file, migrated_file|
        puts "  Validating: #{File.basename(original_file)} → #{File.basename(migrated_file)}"

        validation = @quality_checker.validate_migration(original_file, migrated_file)
        validations << validation

        if validation[:migration_quality] < @options[:quality_threshold]
          puts "    ⚠️  Quality below threshold: #{validation[:migration_quality]}%"
        else
          puts "    ✅ Quality acceptable: #{validation[:migration_quality]}%"
        end

        if @options[:verbose]
          validation[:regression_check].each do |regression|
            puts "    🔸 Regression: #{regression}"
          end
        end
      end

      validations
    end

    def create_migration_plan(analysis_result = nil)
      analysis = analysis_result || @migration_helper.analyze_all_tests

      puts "📋 Creating migration plan..."

      plan = {
        overview: generate_plan_overview(analysis),
        phases: create_migration_phases(analysis),
        effort_estimation: estimate_total_effort(analysis),
        risks_and_mitigations: identify_risks(analysis),
        recommendations: generate_plan_recommendations(analysis)
      }

      plan
    end

    def execute_migration_plan(plan)
      puts "🚀 Executing migration plan..."

      execution_results = []

      plan[:phases].each_with_index do |phase, index|
        puts "\n📍 Phase #{index + 1}: #{phase[:name]}"
        puts "   Target: #{phase[:files].length} files"

        phase_results = process_phase_files(phase[:files])
        execution_results << {
          phase: phase[:name],
          results: phase_results,
          success_rate: calculate_success_rate(phase_results)
        }

        puts "   Success rate: #{execution_results.last[:success_rate]}%"
      end

      execution_results
    end

    private

    def filter_by_target_patterns(legacy_tests, target_patterns)
      legacy_tests.select do |test|
        target_patterns.any? do |pattern|
          case pattern
          when :service
            test[:path].include?('controller') || test[:path].include?('model')
          when :command
            test[:path].include?('controller') || test[:path].include?('request')
          when :policy
            test[:path].include?('controller') || test[:path].include?('feature')
          when :repository
            test[:path].include?('model')
          else
            false
          end
        end
      end
    end

    def process_in_batches(items, &block)
      items.each_slice(@options[:batch_size]) do |batch|
        puts "\n📦 Processing batch of #{batch.length} files..."
        block.call(batch)
      end
    end

    def process_batch(batch)
      batch_results = []

      batch.each do |test_file|
        result = process_single_file(test_file)
        batch_results << result
        @results << result

        print_progress_indicator(result)
      end

      batch_results
    end

    def process_single_file(test_file)
      result = {
        file_path: test_file[:path],
        file_type: test_file[:type],
        status: :pending,
        migrations: [],
        quality_score: 0,
        errors: []
      }

      begin
        # Get migration suggestions
        suggestions = @migration_helper.suggest_migration(test_file[:path])

        if suggestions[:suggestions].empty?
          result[:status] = :no_suggestions
          result[:errors] << "No migration suggestions found"
          return result
        end

        # Generate templates for each suggestion
        suggestions[:suggestions].each do |suggestion|
          template_result = generate_migration_template(test_file, suggestion)
          result[:migrations] << template_result
        end

        # Validate generated templates
        if result[:migrations].any?
          qualities = result[:migrations].map { |m| m[:quality_score] || 0 }
          result[:quality_score] = qualities.max
          result[:status] = :success
        else
          result[:status] = :failed
        end

      rescue => e
        result[:status] = :error
        result[:errors] << e.message
        @errors << {
          type: :file_processing,
          file: test_file[:path],
          error: e.message
        }
      end

      result
    end

    def generate_migration_template(test_file, suggestion)
      template_result = {
        target_pattern: suggestion[:target],
        priority: suggestion[:priority],
        reason: suggestion[:reason],
        file_path: nil,
        quality_score: 0,
        status: :pending
      }

      begin
        template = @migration_helper.generate_template_for_migration(
          test_file[:path],
          suggestion[:target]
        )

        if @options[:dry_run]
          template_result[:status] = :dry_run_success
          template_result[:file_path] = template[:file_path]
        else
          # Write file
          ensure_directory_exists(template[:file_path])

          unless File.exist?(template[:file_path]) || @options[:force_overwrite]
            File.write(template[:file_path], template[:content])
            template_result[:file_path] = template[:file_path]
            template_result[:status] = :written
          else
            template_result[:status] = :skipped_existing
            template_result[:file_path] = template[:file_path]
          end

          # Check quality if written
          if template_result[:status] == :written
            quality_check = @quality_checker.check_file(template[:file_path])
            template_result[:quality_score] = quality_check[:quality_score]
          end
        end

      rescue => e
        template_result[:status] = :error
        template_result[:errors] = [e.message]
      end

      template_result
    end

    def ensure_directory_exists(file_path)
      dir = File.dirname(file_path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end

    def print_progress_indicator(result)
      case result[:status]
      when :success
        print "✅"
      when :no_suggestions
        print "⚪"
      when :failed
        print "❌"
      when :error
        print "🔥"
      else
        print "⏳"
      end
    end

    def generate_plan_overview(analysis)
      {
        total_legacy_tests: analysis[:legacy_tests].length,
        new_architecture_tests: analysis[:new_architecture_tests].length,
        migration_progress: analysis[:statistics][:migration_progress],
        files_with_suggestions: analysis[:statistics][:files_with_suggestions],
        estimated_total_effort: estimate_total_effort(analysis)
      }
    end

    def create_migration_phases(analysis)
      phases = []

      # Phase 1: High priority, low complexity
      phase1_files = select_files_by_priority_and_complexity(analysis, 'high', [1, 2, 3])
      phases << {
        name: 'High Priority - Simple Files',
        files: phase1_files,
        estimated_effort: phase1_files.length * 2, # 2 hours per file
        description: 'Simple migrations with high business value'
      }

      # Phase 2: High priority, medium complexity
      phase2_files = select_files_by_priority_and_complexity(analysis, 'high', [4, 5, 6])
      phases << {
        name: 'High Priority - Medium Complexity',
        files: phase2_files,
        estimated_effort: phase2_files.length * 4, # 4 hours per file
        description: 'Medium complexity migrations with high value'
      }

      # Phase 3: Medium priority
      phase3_files = select_files_by_priority_and_complexity(analysis, 'medium', [1, 2, 3, 4, 5, 6])
      phases << {
        name: 'Medium Priority Files',
        files: phase3_files,
        estimated_effort: phase3_files.length * 3, # 3 hours per file
        description: 'Medium value migrations'
      }

      # Phase 4: Low priority and high complexity
      remaining_files = get_remaining_files(analysis, [phase1_files, phase2_files, phase3_files].flatten)
      phases << {
        name: 'Remaining Files',
        files: remaining_files,
        estimated_effort: remaining_files.length * 5, # 5 hours per file
        description: 'Low priority or high complexity files'
      }

      phases
    end

    def select_files_by_priority_and_complexity(analysis, priority, complexity_range)
      analysis[:migration_suggestions].select do |file_path, suggestions|
        high_priority_suggestions = suggestions.select { |s| s[:priority] == priority }

        if high_priority_suggestions.any?
          file_analysis = @migration_helper.analyze_file(file_path)
          complexity_range.include?(file_analysis[:complexity])
        else
          false
        end
      end.keys
    end

    def get_remaining_files(analysis, excluded_files)
      all_files_with_suggestions = analysis[:migration_suggestions].keys
      all_files_with_suggestions - excluded_files
    end

    def estimate_total_effort(analysis)
      total_effort = 0

      analysis[:migration_suggestions].each do |file_path, suggestions|
        file_analysis = @migration_helper.analyze_file(file_path)

        # Base effort by complexity
        base_effort = case file_analysis[:complexity]
                     when 1..3 then 2  # 2 hours
                     when 4..6 then 4  # 4 hours
                     when 7..8 then 6  # 6 hours
                     else 8            # 8+ hours for complex files
                     end

        # Adjust by number of migration targets
        multiplier = [1, suggestions.length * 0.5].max
        adjusted_effort = base_effort * multiplier

        total_effort += adjusted_effort
      end

      total_effort.round(1)
    end

    def identify_risks(analysis)
      risks = []

      # Analyze complexity risk
      complex_files = 0
      analysis[:migration_suggestions].each do |file_path, _|
        file_analysis = @migration_helper.analyze_file(file_path)
        complex_files += 1 if file_analysis[:complexity] >= 7
      end

      if complex_files > 5
        risks << {
          type: :complexity,
          severity: :high,
          description: "#{complex_files} highly complex files may require significant refactoring",
          mitigation: 'Break down complex files into smaller, focused migrations'
        }
      end

      # Analyze coverage risk
      if analysis[:statistics][:migration_progress] < 50
        risks << {
          type: :coverage,
          severity: :medium,
          description: 'Low migration coverage may indicate architectural gaps',
          mitigation: 'Review migration strategy and consider additional patterns'
        }
      end

      risks
    end

    def generate_plan_recommendations(analysis)
      recommendations = []

      # Based on success patterns
      if analysis[:new_architecture_tests].length > 0
        recommendations << 'Leverage existing new architecture patterns as templates'
      end

      # Based on file types
      legacy_by_type = analysis[:statistics][:legacy_by_type]
      if legacy_by_type[:model] && legacy_by_type[:model] > 10
        recommendations << 'Focus on Service pattern for model business logic extraction'
      end

      if legacy_by_type[:controller] && legacy_by_type[:controller] > 10
        recommendations << 'Prioritize Command pattern for controller action extraction'
      end

      recommendations << 'Set up regular quality checks during migration process'
      recommendations << 'Establish migration progress tracking and reporting'

      recommendations
    end

    def process_phase_files(phase_files)
      phase_results = []

      phase_files.each do |file_path|
        result = process_single_file({ path: file_path, type: 'unknown' })
        phase_results << result
      end

      phase_results
    end

    def calculate_success_rate(results)
      return 0 if results.empty?

      successful = results.count { |r| r[:status] == :success }
      (successful.to_f / results.length * 100).round(1)
    end

    def generate_batch_report
      puts "\n📊 Batch Migration Report"
      puts "=" * 50

      total_files = @results.length
      successful = @results.count { |r| r[:status] == :success }
      failed = @results.count { |r| r[:status] == :failed || r[:status] == :error }
      no_suggestions = @results.count { |r| r[:status] == :no_suggestions }

      puts "Total files processed: #{total_files}"
      puts "✅ Successful: #{successful}"
      puts "❌ Failed: #{failed}"
      puts "⚪ No suggestions: #{no_suggestions}"
      puts "Success rate: #{(successful.to_f / total_files * 100).round(1)}%"

      if @results.any?
        avg_quality = @results.map { |r| r[:quality_score] }.sum / @results.length
        puts "Average quality score: #{avg_quality.round(1)}"
      end

      if @errors.any?
        puts "\n❌ Errors encountered:"
        @errors.each do |error|
          puts "  #{error[:type]}: #{error[:error]}"
        end
      end

      {
        total_files: total_files,
        successful: successful,
        failed: failed,
        no_suggestions: no_suggestions,
        success_rate: (successful.to_f / total_files * 100).round(1),
        average_quality: @results.any? ? (@results.map { |r| r[:quality_score] }.sum / @results.length).round(1) : 0,
        errors: @errors
      }
    end
  end
end