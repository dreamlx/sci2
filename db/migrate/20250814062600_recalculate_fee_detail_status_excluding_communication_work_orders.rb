class RecalculateFeeDetailStatusExcludingCommunicationWorkOrders < ActiveRecord::Migration[7.0]
  def up
    say '开始重新计算费用明细状态，排除沟通工单影响...'

    # 统计信息
    total_fee_details = FeeDetail.count
    updated_count = 0

    say "总共需要处理 #{total_fee_details} 个费用明细"

    # 分批处理，避免内存问题
    FeeDetail.find_in_batches(batch_size: 100) do |batch|
      batch.each do |fee_detail|
        old_status = fee_detail.verification_status

        # 使用更新后的服务重新计算状态
        FeeDetailStatusService.new([fee_detail.id]).update_status

        fee_detail.reload
        new_status = fee_detail.verification_status

        if old_status != new_status
          updated_count += 1
          say "费用明细 ##{fee_detail.id}: #{old_status} -> #{new_status}"
        end
      end
    end

    say '状态重新计算完成！'
    say "总处理: #{total_fee_details} 个费用明细"
    say "状态变更: #{updated_count} 个费用明细"

    # 更新报销单状态
    say '开始更新报销单状态...'
    reimbursement_updated = 0

    Reimbursement.find_each do |reimbursement|
      old_status = reimbursement.status
      reimbursement.update_status_based_on_fee_details!

      if reimbursement.status != old_status
        reimbursement_updated += 1
        say "报销单 ##{reimbursement.id}: #{old_status} -> #{reimbursement.status}"
      end
    end

    say "报销单状态更新完成！更新了 #{reimbursement_updated} 个报销单"
  end

  def down
    say '此迁移不支持回滚，如需恢复请重新运行状态计算'
  end
end
