# frozen_string_literal: true

# Fix ActiveAdmin CSV export encoding issues
require 'inherited_resources'

Rails.application.config.after_initialize do
  ActiveAdmin::ResourceController.class_eval do
    # Override csv_filename method to add timestamp
    def csv_filename
      "#{resource_collection_name}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
    end

    # Add UTF-8 BOM for Excel compatibility
    alias_method :original_index, :index
    def index(&block)
      # 只在 CSV 请求时才应用 UTF-8 BOM
      if request.format.csv?
        original_index(&block)
        response.body = "\xEF\xBB\xBF" + response.body
      else
        original_index(&block)
      end
    end
  end
end
