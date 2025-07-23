# frozen_string_literal: true

# 修复 ActiveAdmin CSV 导出的编码问题
# 添加 UTF-8 BOM 以便 Excel 正确识别 UTF-8 编码的 CSV 文件
ActiveAdmin::ResourceController.class_eval do
  # 重写 csv_filename 方法以添加当前时间戳
  def csv_filename
    "#{resource_collection_name}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
  end
  
  # 重写 index 方法以添加 UTF-8 BOM
  alias_method :original_index, :index
  def index(options={}, &block)
    original_index(options, &block)
    
    if request.format.to_s == 'text/csv'
      response.body = "\xEF\xBB\xBF" + response.body
    end
  end
end