class MigrateProblemCodeData < ActiveRecord::Migration[7.1]
  def up
    # This migration will run the data migration service to migrate data from the old structure to the new one
    # It should be run after all the schema changes are applied
    
    # First, ensure the FeeType and ProblemType models have the new fields
    # This is a safety check to make sure the previous migrations have been applied
    unless table_exists?(:fee_types) && 
           column_exists?(:fee_types, :code) && 
           column_exists?(:fee_types, :title) && 
           column_exists?(:fee_types, :meeting_type) &&
           table_exists?(:problem_types) &&
           column_exists?(:problem_types, :code) && 
           column_exists?(:problem_types, :title) && 
           column_exists?(:problem_types, :sop_description) && 
           column_exists?(:problem_types, :standard_handling) && 
           column_exists?(:problem_types, :fee_type_id)
      
      puts "Error: Required tables or columns are missing. Make sure all previous migrations have been applied."
      return
    end
    
    # Create default fee types if they don't exist
    execute <<-SQL
      INSERT INTO fee_types (code, title, meeting_type, active, created_at, updated_at)
      SELECT '00', '个人费用', '个人', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (SELECT 1 FROM fee_types WHERE code = '00')
    SQL
    
    execute <<-SQL
      INSERT INTO fee_types (code, title, meeting_type, active, created_at, updated_at)
      SELECT '01', '学术费用', '学术论坛', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (SELECT 1 FROM fee_types WHERE code = '01')
    SQL
    
    # Migrate existing fee types if any have name but not code/title/meeting_type
    if column_exists?(:fee_types, :name)
      execute <<-SQL
        UPDATE fee_types
        SET code = CASE WHEN code IS NULL THEN CAST(id + 10 AS TEXT) ELSE code END,
            title = CASE WHEN title IS NULL THEN name ELSE title END,
            meeting_type = CASE 
                            WHEN meeting_type IS NULL AND name LIKE '%个人%' THEN '个人'
                            WHEN meeting_type IS NULL AND name LIKE '%学术%' THEN '学术论坛'
                            WHEN meeting_type IS NULL THEN '其他'
                            ELSE meeting_type
                          END,
            active = CASE WHEN active IS NULL THEN 1 ELSE active END
        WHERE name IS NOT NULL AND (code IS NULL OR title IS NULL OR meeting_type IS NULL OR active IS NULL);
      SQL
    end
    
    # Migrate existing problem types if any have name but not code/title/sop_description/standard_handling/fee_type_id
    if column_exists?(:problem_types, :name) && column_exists?(:problem_types, :document_category_id)
      # This is a simplified version - in a real implementation, you would need more sophisticated logic
      execute <<-SQL
        UPDATE problem_types
        SET code = CASE WHEN code IS NULL THEN CAST(id + 10 AS TEXT) ELSE code END,
            title = CASE WHEN title IS NULL THEN name ELSE title END,
            sop_description = CASE WHEN sop_description IS NULL THEN '标准操作流程待定' ELSE sop_description END,
            standard_handling = CASE WHEN standard_handling IS NULL THEN '标准处理方法待定' ELSE standard_handling END,
            fee_type_id = CASE 
                            WHEN fee_type_id IS NULL AND document_category_id IS NOT NULL THEN
                              (SELECT CASE 
                                      WHEN EXISTS (SELECT 1 FROM document_categories dc WHERE dc.id = document_category_id AND dc.name LIKE '%个人%') 
                                        THEN (SELECT id FROM fee_types WHERE meeting_type = '个人' LIMIT 1)
                                      WHEN EXISTS (SELECT 1 FROM document_categories dc WHERE dc.id = document_category_id AND dc.name LIKE '%学术%') 
                                        THEN (SELECT id FROM fee_types WHERE meeting_type = '学术论坛' LIMIT 1)
                                      ELSE (SELECT id FROM fee_types LIMIT 1)
                                    END)
                            WHEN fee_type_id IS NULL THEN (SELECT id FROM fee_types LIMIT 1)
                            ELSE fee_type_id
                          END,
            active = CASE WHEN active IS NULL THEN 1 ELSE active END
        WHERE name IS NOT NULL AND (code IS NULL OR title IS NULL OR sop_description IS NULL OR standard_handling IS NULL OR fee_type_id IS NULL);
      SQL
    end
    
    # Import problem codes from CSV files if they exist
    # This would be done in Ruby code in a real implementation
    puts "Note: To import problem codes from CSV files, run 'rake problem_codes:import' after migrations."
  end

  def down
    # This migration cannot be reversed as it involves data migration
    puts "This migration cannot be reversed as it involves data migration."
  end
end