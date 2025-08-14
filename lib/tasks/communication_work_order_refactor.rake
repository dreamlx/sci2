namespace :communication_work_order do
  desc "重新计算费用明细状态，排除沟通工单影响"
  task recalculate_status: :environment do
    puts "开始重新计算费用明细状态..."
    
    total_fee_details = FeeDetail.count
    updated_count = 0
    
    puts "总共需要处理 #{total_fee_details} 个费用明细"
    
    FeeDetail.find_in_batches(batch_size: 100) do |batch|
      batch.each do |fee_detail|
        old_status = fee_detail.verification_status
        
        # 使用更新后的服务重新计算状态
        FeeDetailStatusService.new([fee_detail.id]).update_status
        
        fee_detail.reload
        new_status = fee_detail.verification_status
        
        if old_status != new_status
          updated_count += 1
          puts "费用明细 ##{fee_detail.id}: #{old_status} -> #{new_status}"
        end
      end
    end
    
    puts "状态重新计算完成！"
    puts "总处理: #{total_fee_details} 个费用明细"
    puts "状态变更: #{updated_count} 个费用明细"
  end

  desc "更新所有报销单状态"
  task update_reimbursement_status: :environment do
    puts "开始更新报销单状态..."
    
    updated_count = 0
    
    Reimbursement.find_each do |reimbursement|
      old_status = reimbursement.status
      reimbursement.update_status_based_on_fee_details!
      
      if reimbursement.status != old_status
        updated_count += 1
        puts "报销单 ##{reimbursement.id}: #{old_status} -> #{reimbursement.status}"
      end
    end
    
    puts "报销单状态更新完成！更新了 #{updated_count} 个报销单"
  end

  desc "完整的状态重新计算（费用明细 + 报销单）"
  task full_recalculate: :environment do
    Rake::Task['communication_work_order:recalculate_status'].invoke
    Rake::Task['communication_work_order:update_reimbursement_status'].invoke
    puts "所有状态重新计算完成！"
  end

  desc "检查沟通工单对状态的影响"
  task check_impact: :environment do
    puts "检查沟通工单对费用明细状态的影响..."
    
    # 统计有沟通工单关联的费用明细
    fee_details_with_comm_wo = FeeDetail.joins(:work_orders)
                                        .where(work_orders: { type: 'CommunicationWorkOrder' })
                                        .distinct
    
    puts "有沟通工单关联的费用明细数量: #{fee_details_with_comm_wo.count}"
    
    # 检查这些费用明细的状态分布
    status_distribution = fee_details_with_comm_wo.group(:verification_status).count
    puts "状态分布:"
    status_distribution.each do |status, count|
      puts "  #{status}: #{count}"
    end
    
    # 检查只有沟通工单的费用明细
    only_comm_wo = FeeDetail.joins(:work_orders)
                            .where(work_orders: { type: 'CommunicationWorkOrder' })
                            .where.not(id: FeeDetail.joins(:work_orders)
                                                   .where.not(work_orders: { type: 'CommunicationWorkOrder' })
                                                   .select(:id))
    
    puts "只有沟通工单关联的费用明细数量: #{only_comm_wo.count}"
    
    if only_comm_wo.any?
      puts "这些费用明细在重构后状态将变为 pending"
    end
  end

  desc "清理现有沟通工单的状态"
  task cleanup_communication_work_orders: :environment do
    puts "开始清理沟通工单状态..."
    
    updated_count = 0
    
    CommunicationWorkOrder.where.not(status: 'completed').find_each do |wo|
      wo.update_column(:status, 'completed')
      updated_count += 1
      puts "沟通工单 ##{wo.id} 状态更新为 completed"
    end
    
    puts "沟通工单状态清理完成！更新了 #{updated_count} 个工单"
  end
end