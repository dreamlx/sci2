# frozen_string_literal: true

# Helper methods for test migration development
module MigrationHelper
  def expect_service_structure(test_file)
    content = File.read(test_file)

    expect(content).to match(/type: :service/)
    expect(content).to match(/describe.*#call/)
    expect(content).to match(/context.*valid/)
    expect(content).to match(/context.*invalid/)
  end

  def expect_command_structure(test_file)
    content = File.read(test_file)

    expect(content).to match(/type: :command/)
    expect(content).to match(/describe.*#call/)
    expect(content).to match(/result\.success\?/)
    expect(content).to match(/ActiveModel validations/)
  end

  def expect_policy_structure(test_file)
    content = File.read(test_file)

    expect(content).to match(/type: :policy/)
    expect(content).to match(/context.*super admin/)
    expect(content).to match(/context.*regular admin/)
    expect(content).to match(/authorization_error_message/)
  end

  def expect_repository_structure(test_file)
    content = File.read(test_file)

    expect(content).to match(/type: :repository/)
    expect(content).to match(/describe.*\.find/)
    expect(content).to match(/describe.*\.by_status/)
    expect(content).to match(/safe_find/)
  end

  def count_test_patterns(content)
    {
      describe_blocks: content.scan(/describe\s+['"]/).length,
      context_blocks: content.scan(/context\s+['"]/).length,
      it_blocks: content.scan(/it\s+['"]/).length,
      let_definitions: content.scan(/let\s+[:]/).length,
      expectations: content.scan(/expect\(/).length
    }
  end

  def verify_migration_quality(original_file, migrated_file, min_quality = 75)
    original_analysis = analyze_test_file(original_file)
    migrated_analysis = analyze_test_file(migrated_file)

    # Check that we haven't lost test cases
    expect(migrated_analysis[:it_blocks]).to be >= original_analysis[:it_blocks] * 0.8

    # Check structure improvements
    expect(migrated_analysis[:context_blocks]).to be >= original_analysis[:context_blocks]
    expect(migrated_analysis[:let_definitions]).to be >= original_analysis[:let_definitions]

    # Check overall quality
    quality_score = calculate_quality_score(migrated_analysis)
    expect(quality_score).to be >= min_quality
  end

  private

  def analyze_test_file(file_path)
    content = File.read(file_path)
    count_test_patterns(content)
  end

  def calculate_quality_score(analysis)
    score = 0
    score += analysis[:describe_blocks] * 5
    score += analysis[:context_blocks] * 10
    score += analysis[:let_definitions] * 5
    score += analysis[:expectations] * 2
    score += analysis[:it_blocks] * 3

    # Normalize to 0-100 scale
    [100, score].min
  end
end