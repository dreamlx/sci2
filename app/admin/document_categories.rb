ActiveAdmin.register DocumentCategory do
  # 添加这行参数许可
  permit_params :name, :keywords, :active

  index do
    selectable_column
    id_column
    column :name
    column :keywords do |cat|
      cat.keyword_list.join(', ')
    end
    column :active
    column :created_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :name
      f.input :keywords, 
              hint: '多个关键词用英文逗号分隔，例如：差旅,交通,住宿'
      f.input :active
    end
    f.actions
  end
end
