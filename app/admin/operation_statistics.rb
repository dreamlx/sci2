# app/admin/operation_statistics.rb
ActiveAdmin.register_page 'Operation Statistics' do
  menu label: '操作统计', priority: 10

  content title: '操作统计' do
    columns do
      column do
        panel '按操作类型统计' do
          pie_chart(WorkOrderOperation.group(:operation_type).count.transform_keys do |k|
            WorkOrderOperation.new(operation_type: k).operation_type_display
          end)
        end
      end

      column do
        panel '按操作人统计' do
          pie_chart WorkOrderOperation.joins(:admin_user).group('admin_users.email').count
        end
      end
    end

    columns do
      column do
        panel '最近30天操作趋势' do
          line_chart WorkOrderOperation.where('created_at >= ?', 30.days.ago)
                                       .group_by_day(:created_at)
                                       .count
        end
      end
    end

    panel '操作排行榜' do
      table_for AdminUser.joins(:work_order_operations)
                         .select('admin_users.*, COUNT(work_order_operations.id) as operations_count')
                         .group('admin_users.id')
                         .order('operations_count DESC')
                         .limit(10) do
        column :email
        column '操作数量' do |admin_user|
          admin_user.operations_count
        end
      end
    end
  end
end
