# frozen_string_literal: true

require_relative '../test_migration/template_generator'
require_relative '../test_migration/migration_helper'
require_relative '../test_migration/quality_checker'
require_relative '../test_migration/batch_processor'

namespace :test_migration do
  desc "Analyze all legacy tests and generate migration suggestions"
  task :analyze_all => :environment do
    puts "🔍 Analyzing all legacy tests..."

    helper = TestMigration::MigrationHelper.new
    analysis = helper.analyze_all_tests

    puts "\n📊 Analysis Summary:"
    puts "Total test files: #{analysis[:statistics][:total_test_files]}"
    puts "Legacy tests: #{analysis[:statistics][:legacy_tests]}"
    puts "New architecture tests: #{analysis[:statistics][:new_architecture_tests]}"
    puts "Migration progress: #{analysis[:statistics][:migration_progress]}%"
    puts "Files with suggestions: #{analysis[:statistics][:files_with_suggestions]}"

    puts "\n📈 Legacy Tests by Type:"
    analysis[:statistics][:legacy_by_type].each do |type, count|
      puts "  #{type}: #{count}"
    end

    puts "\n🏗️ New Architecture Tests by Type:"
    analysis[:statistics][:new_architecture_by_type].each do |type, count|
      puts "  #{type}: #{count}"
    end

    if analysis[:migration_suggestions].any?
      puts "\n💡 Top Migration Suggestions:"
      analysis[:migration_suggestions].first(10).each do |file_path, suggestions|
        puts "  #{File.basename(file_path)}:"
        suggestions.each do |suggestion|
          puts "    → #{suggestion[:target]} (#{suggestion[:priority]}): #{suggestion[:reason]}"
        end
      end
    end

    # Save detailed analysis to file
    output_file = Rails.root.join('tmp', 'test_migration_analysis.json')
    File.write(output_file, JSON.pretty_generate(analysis))
    puts "\n📄 Detailed analysis saved to: #{output_file}"
  end

  desc "Generate test template for specific pattern and class"
  task :generate_template, [:pattern, :class_name] => :environment do |t, args|
    pattern = args[:pattern]
    class_name = args[:class_name]

    unless pattern && class_name
      puts "Usage: rake test_migration:generate_template[pattern,class_name]"
      puts "Patterns: service, command, policy, repository"
      next
    end

    puts "📝 Generating #{pattern} template for #{class_name}..."

    begin
      generator = TestMigration::TemplateGenerator.new(pattern, class_name)
      result = generator.write_to_file

      if result
        puts "✅ Template generated successfully: #{generator.send(:target_file_path)}"
      else
        puts "⚠️  File already exists or generation failed"
      end
    rescue => e
      puts "❌ Error generating template: #{e.message}"
    end
  end

  desc "Generate batch templates for multiple patterns and classes"
  task :generate_batch => :environment do
    patterns = [:service, :command, :policy, :repository]
    class_names = [
      'UserService', 'ReimbursementService', 'AttachmentService',
      'CreateReimbursementCommand', 'UpdateStatusCommand', 'AssignTaskCommand',
      'UserPolicy', 'ReimbursementPolicy', 'AdminPolicy',
      'UserRepository', 'ReimbursementRepository', 'FeeDetailRepository'
    ]

    puts "📝 Generating batch templates..."

    processor = TestMigration::BatchProcessor.new(dry_run: false)
    templates = processor.generate_templates_for_patterns(patterns, class_names)

    puts "✅ Generated #{templates.length} templates"
  end

  desc "Validate migration quality between original and migrated files"
  task :validate_migration, [:original_file, :migrated_file] => :environment do |t, args|
    original = args[:original_file]
    migrated = args[:migrated_file]

    unless original && migrated
      puts "Usage: rake test_migration:validate_migration[original_file,migrated_file]"
      puts "Example: rake test_migration:validate_migration[spec/models/user_spec.rb,spec/services/user_service_spec.rb]"
      next
    end

    puts "🔍 Validating migration quality..."

    checker = TestMigration::QualityChecker.new
    validation = checker.validate_migration(original, migrated)

    puts "\n📊 Migration Validation Results:"
    puts "Quality Score: #{validation[:migration_quality]}%"
    puts "Overall Assessment: #{validation[:overall_assessment]}"

    puts "\n✅ Completeness Check (Score: #{validation[:completeness_check][:score]}%):"
    validation[:completeness_check][:issues].each do |issue|
      puts "  ⚠️  #{issue}"
    end

    puts "\n📈 Improvements:"
    validation[:improvement_check].each do |improvement|
      puts "  ✨ #{improvement}"
    end

    puts "\n⚠️  Regressions:"
    validation[:regression_check].each do |regression|
      puts "  🔻 #{regression}"
    end
  end

  desc "Check quality of test files in directory"
  task :quality_check, [:directory, :pattern] => :environment do |t, args|
    directory = args[:directory] || 'spec'
    pattern = args[:pattern]

    puts "🔍 Checking quality for #{directory}..."

    checker = TestMigration::QualityChecker.new
    report = checker.generate_quality_report(directory)

    puts "\n📊 Quality Report Summary:"
    puts "Total files: #{report[:summary][:total_files]}"
    puts "Average quality: #{report[:summary][:average_quality]}%"
    puts "Files with issues: #{report[:summary][:files_with_issues]}"
    puts "Perfect files (90%+): #{report[:summary][:files_perfect]}"

    puts "\n📈 Quality Distribution:"
    report[:summary][:quality_distribution].each do |range, count|
      puts "  #{range}-#{range + 9}%: #{count} files"
    end

    puts "\n🏗️ Quality by Pattern Type:"
    report[:by_pattern_type].each do |type, stats|
      puts "  #{type}: #{stats[:count]} files, avg #{stats[:average_quality]}%"
      if stats[:common_issues].any?
        puts "    Common issues:"
        stats[:common_issues].first(3).each do |issue, count|
          puts "      #{count}x: #{issue}"
        end
      end
    end

    puts "\n💡 Top Recommendations:"
    report[:recommendations].first(5).each do |rec|
      puts "  #{rec[:frequency]}x: #{rec[:recommendation]}"
    end

    # Save detailed report to file
    output_file = Rails.root.join('tmp', 'test_quality_report.json')
    File.write(output_file, JSON.pretty_generate(report))
    puts "\n📄 Detailed report saved to: #{output_file}"
  end

  desc "Execute batch migration of legacy tests (dry run)"
  task :batch_migrate, [:dry_run, :target_patterns] => :environment do |t, args|
    dry_run = args[:dry_run] != 'false'
    target_patterns = args[:target_patterns]&.split(',')&.map(&:to_sym)

    puts "🔄 Starting batch migration..."
    puts "Dry run: #{dry_run ? 'ENABLED' : 'DISABLED'}"
    puts "Target patterns: #{target_patterns&.join(', ') || 'ALL'}"

    processor = TestMigration::BatchProcessor.new(
      dry_run: dry_run,
      force_overwrite: false,
      quality_threshold: 70,
      verbose: true
    )

    results = processor.process_all_legacy_tests(target_patterns)

    puts "\n🏁 Batch Migration Complete!"
    puts "Success rate: #{results[:success_rate]}%"
    puts "Average quality: #{results[:average_quality]}%"

    if results[:errors].any?
      puts "\n❌ Errors encountered:"
      results[:errors].each do |error|
        puts "  #{error[:type]}: #{error[:error]}"
      end
    end
  end

  desc "Create detailed migration plan"
  task :create_migration_plan => :environment do
    puts "📋 Creating migration plan..."

    processor = TestMigration::BatchProcessor.new
    plan = processor.create_migration_plan

    puts "\n🗺️ Migration Plan Overview:"
    overview = plan[:overview]
    puts "Total legacy tests: #{overview[:total_legacy_tests]}"
    puts "New architecture tests: #{overview[:new_architecture_tests]}"
    puts "Current migration progress: #{overview[:migration_progress]}%"
    puts "Files needing migration: #{overview[:files_with_suggestions]}"
    puts "Estimated total effort: #{overview[:estimated_total_effort]} hours"

    puts "\n📅 Migration Phases:"
    plan[:phases].each_with_index do |phase, index|
      puts "  Phase #{index + 1}: #{phase[:name]}"
      puts "    Files: #{phase[:files].length}"
      puts "    Estimated effort: #{phase[:estimated_effort]} hours"
      puts "    Description: #{phase[:description]}"
    end

    puts "\n⚠️  Risks and Mitigations:"
    plan[:risks_and_mitigations].each do |risk|
      puts "  #{risk[:severity].upcase}: #{risk[:description]}"
      puts "    Mitigation: #{risk[:mitigation]}"
    end

    puts "\n💡 Recommendations:"
    plan[:recommendations].each_with_index do |rec, index|
      puts "  #{index + 1}. #{rec}"
    end

    # Save plan to file
    output_file = Rails.root.join('tmp', 'test_migration_plan.json')
    File.write(output_file, JSON.pretty_generate(plan))
    puts "\n📄 Migration plan saved to: #{output_file}"
  end

  desc "Generate progress report for migration monitoring"
  task :progress_report => :environment do
    puts "📊 Generating migration progress report..."

    helper = TestMigration::MigrationHelper.new
    analysis = helper.analyze_all_tests
    checker = TestMigration::QualityChecker.new

    # Calculate current progress
    total_tests = analysis[:statistics][:total_test_files]
    new_arch_tests = analysis[:statistics][:new_architecture_tests]
    progress_percentage = analysis[:statistics][:migration_progress]

    # Quality metrics for new architecture tests
    new_arch_quality = 0
    if analysis[:new_architecture_tests].any?
      total_quality = 0
      analysis[:new_architecture_tests].each do |test|
        quality_check = checker.check_file(test[:path], test[:type])
        total_quality += quality_check[:quality_score] unless quality_check[:error]
      end
      new_arch_quality = (total_quality.to_f / analysis[:new_architecture_tests].length).round(1)
    end

    puts "\n📈 Migration Progress Report"
    puts "=" * 40
    puts "📊 Overall Progress:"
    puts "  Total test files: #{total_tests}"
    puts "  New architecture: #{new_arch_tests}"
    puts "  Migration progress: #{progress_percentage}%"
    puts "  New architecture quality: #{new_arch_quality}%"

    puts "\n🏗️ New Architecture Distribution:"
    analysis[:statistics][:new_architecture_by_type].each do |type, count|
      percentage = total_tests > 0 ? (count.to_f / total_tests * 100).round(1) : 0
      puts "  #{type}: #{count} files (#{percentage}% of total)"
    end

    puts "\n📋 Remaining Migration Targets:"
    analysis[:statistics][:legacy_by_type].each do |type, count|
      puts "  #{type}: #{count} files remaining"
    end

    # Calculate migration velocity (if we have historical data)
    puts "\n🚀 Migration Metrics:"
    puts "  Files with suggestions: #{analysis[:statistics][:files_with_suggestions]}"
    puts "  Average migrations per file: #{calculate_average_migrations(analysis)}"
    puts "  Estimated completion: #{estimate_completion_date(progress_percentage)}"

    # Save progress report
    progress_data = {
      timestamp: Time.current.iso8601,
      total_tests: total_tests,
      new_architecture_tests: new_arch_tests,
      migration_progress: progress_percentage,
      new_architecture_quality: new_arch_quality,
      distribution: analysis[:statistics]
    }

    output_file = Rails.root.join('tmp', 'migration_progress.json')
    File.write(output_file, JSON.pretty_generate(progress_data))
    puts "\n📄 Progress report saved to: #{output_file}"
  end

  desc "Execute full migration workflow (analyze -> plan -> batch migrate dry run)"
  task :full_workflow => :environment do
    puts "🚀 Starting full migration workflow..."

    puts "\n1️⃣ Analyzing legacy tests..."
    Rake::Task['test_migration:analyze_all'].invoke

    puts "\n2️⃣ Creating migration plan..."
    Rake::Task['test_migration:create_migration_plan'].invoke

    puts "\n3️⃣ Running dry-run batch migration..."
    Rake::Task['test_migration:batch_migrate'].invoke(true, nil)

    puts "\n4️⃣ Checking new architecture quality..."
    checker = TestMigration::QualityChecker.new
    new_arch_report = checker.check_directory('spec/services', 'service')

    if new_arch_report[:error]
      puts "⚠️  Could not check service directory: #{new_arch_report[:error]}"
    else
      puts "📊 New Architecture Quality Summary:"
      puts "  Files: #{new_arch_report[:summary][:total_files]}"
      puts "  Average quality: #{new_arch_report[:summary][:average_quality]}%"
    end

    puts "\n✅ Full workflow completed!"
    puts "📄 Check tmp/ directory for detailed reports and plans"
  end

  private

  def calculate_average_migrations(analysis)
    total_suggestions = 0
    files_with_suggestions = 0

    analysis[:migration_suggestions].each do |_, suggestions|
      total_suggestions += suggestions.length
      files_with_suggestions += 1
    end

    files_with_suggestions > 0 ? (total_suggestions.to_f / files_with_suggestions).round(2) : 0
  end

  def estimate_completion_date(current_progress)
    if current_progress >= 100
      return "Completed ✅"
    elsif current_progress == 0
      return "Not started"
    else
      # Simple linear extrapolation - adjust based on your team velocity
      remaining_percentage = 100 - current_progress
      estimated_weeks = (remaining_percentage / 5.0).round(1) # Assuming 5% per week
      "#{estimated_weeks} weeks (at current velocity)"
    end
  end
end