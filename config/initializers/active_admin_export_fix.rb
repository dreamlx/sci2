# frozen_string_literal: true

# Enhanced ActiveAdmin export functionality with proper encoding and Excel support
require 'inherited_resources'

Rails.application.config.after_initialize do
  ActiveAdmin::ResourceController.class_eval do
    # Override csv_filename method to add timestamp
    def csv_filename
      "#{resource_collection_name}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    end
    
    # Enhanced CSV export with proper encoding for Windows compatibility
    # Only override if not already overridden by other initializers
    unless instance_methods(false).include?(:original_index_with_export)
      alias_method :original_index_with_export, :index
      def index(&block)
        # Handle different export formats
        case request.format.symbol
        when :csv
          handle_csv_export(&block)
        when :xlsx
          handle_excel_export(&block)
        else
          original_index_with_export(&block)
        end
      end
    end
    
    private
    
    def handle_csv_export(&block)
      original_index_with_export(&block)
      
      # Add UTF-8 BOM for Excel compatibility and ensure proper encoding
      if response.body.present?
        # Ensure the content is properly encoded as UTF-8
        encoded_content = response.body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        
        # Add BOM for Excel compatibility
        response.body = "\xEF\xBB\xBF" + encoded_content
        
        # Set proper headers for Windows compatibility
        response.headers['Content-Type'] = 'text/csv; charset=utf-8'
        response.headers['Content-Disposition'] = "attachment; filename=\"#{csv_filename}\"; filename*=UTF-8''#{csv_filename}"
      end
    end
    
    def handle_excel_export(&block)
      # For Excel export, we'll use the built-in ActiveAdmin functionality
      # but ensure proper permissions and encoding
      original_index_with_export(&block)
      
      if response.body.present?
        # Parse the CSV data that ActiveAdmin generates
        csv_data = response.body.sub(/^\xEF\xBB\xBF/, '') # Remove BOM if present
        require 'csv'
        
        # Parse CSV data
        csv = CSV.parse(csv_data, headers: true)
        
        # Generate Excel file using the same data as CSV
        excel_data = generate_excel_from_csv(csv)
        
        # Set response for Excel file
        response.body = excel_data
        response.headers['Content-Type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        response.headers['Content-Disposition'] = "attachment; filename=\"#{resource_collection_name}_#{Time.current.strftime('%Y%m%d%H%M%S')}.xlsx\""
      end
    end
    
    def generate_excel_from_csv(csv)
      require 'rubyXL'
      
      # Create a new workbook
      workbook = RubyXL::Workbook.new
      worksheet = workbook[0]
      
      # Add headers
      if csv.headers.any?
        csv.headers.each_with_index do |header, col_index|
          worksheet.add_cell(0, col_index, header.to_s)
        end
      end
      
      # Add data rows
      csv.each_with_index do |row, row_index|
        row.cells.each_with_index do |cell, col_index|
          value = cell.value
          
          # Handle different data types
          if value.is_a?(Numeric)
            worksheet.add_cell(row_index + 1, col_index, value)
          elsif value.is_a?(Date) || value.is_a?(Time)
            worksheet.add_cell(row_index + 1, col_index, value.strftime('%Y-%m-%d %H:%M:%S'))
          else
            worksheet.add_cell(row_index + 1, col_index, value.to_s)
          end
        end
      end
      
      # Auto-size columns
      (0...csv.headers.length).each do |col_index|
        worksheet.change_column_width(col_index, 15)
      end
      
      # Return the Excel file as a string
      workbook.stream.read
    rescue LoadError => e
      # Fallback to CSV if RubyXL is not available
      Rails.logger.warn "RubyXL gem not available, falling back to CSV export: #{e.message}"
      return csv.to_s # Return CSV string as fallback
    rescue => e
      Rails.logger.error "Excel generation failed: #{e.message}"
      return csv.to_s # Return CSV string as fallback
    end
    
    def resource_collection_name
      active_admin_config.resource_label.downcase.gsub(/\s+/, '_')
    end
  end
end
