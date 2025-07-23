# ActiveAdmin CSV 修复代码

以下是修复 ActiveAdmin CSV 导出编码问题的初始化文件代码。请将此代码保存到 `config/initializers/active_admin_csv_fix.rb` 文件中：

```ruby
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
```

## 使用说明

1. 创建文件 `config/initializers/active_admin_csv_fix.rb`
2. 将上述代码复制到该文件中
3. 重启 Rails 应用程序以使更改生效
4. 测试 CSV 导出功能，确认中文字符能够正确显示

## 代码解释

- `\xEF\xBB\xBF` 是 UTF-8 BOM（字节顺序标记），它告诉 Excel 这个文件使用 UTF-8 编码
- 我们在 `index` 方法中检查请求格式是否为 CSV，如果是，则在响应体前添加 BOM
- 我们还修改了 `csv_filename` 方法，为导出的 CSV 文件添加时间戳，使文件名更具辨识度

## 注意事项

- 此修复仅适用于 ActiveAdmin 内置的 CSV 导出功能
- 如果您有自定义的 CSV 导出功能，需要单独修改这些方法
- 修改后请在中文 Windows 系统上测试，确保问题已解决