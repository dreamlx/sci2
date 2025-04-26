ActiveAdmin.setup do |config|
  # 设置站点标题
  config.site_title = "SCI2工单系统"
  
  # 设置默认命名空间
  config.default_namespace = :admin
  
  # 设置根路径
  config.root_to = 'dashboard#index'
  
  # 启用批量操作
  config.batch_actions = true
  
  # 设置每页显示记录数
  config.default_per_page = 30
  
  # 设置CSV下载选项
  config.csv_options = { col_sep: ',', force_quotes: true }
  
  
  
  # 设置注释
  config.comments = false
end
