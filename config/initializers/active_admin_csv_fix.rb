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
    def index(options={}, &block)
      original_index(options, &block)
      
      if request.format.csv?
        response.body = "\xEF\xBB\xBF" + response.body
      end
    end
  end
end