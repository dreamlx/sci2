class FixFlexField7ForPersonalReimbursements < ActiveRecord::Migration[7.1]
  def change
    say_with_time 'Populating flex_field_7 for FeeDetails of personal reimbursements' do
      # 1. 查找所有相关的报销单的 invoice_number
      # 使用正确的关联：Reimbursement.invoice_number <-> FeeDetail.document_number
      invoice_numbers = Reimbursement.where('document_name LIKE ?', '%个人日常%').pluck(:invoice_number)

      # 2. 查找所有需要修复的 FeeDetail 记录（通过 document_number 关联）
      fee_details_to_fix = FeeDetail.where(document_number: invoice_numbers)
                                    .where(flex_field_7: [nil, ''])

      # 3. 构建 FeeType 的 `meeting_name` 映射，避免 N+1 查询
      fee_type_names = fee_details_to_fix.pluck(:fee_type).uniq
      fee_types_map = FeeType.where(name: fee_type_names).pluck(:name, :meeting_name).to_h

      # 4. 分批更新 FeeDetail
      updated_count = 0
      fee_details_to_fix.in_batches.each_record do |fee_detail|
        meeting_name = fee_types_map[fee_detail.fee_type]

        if meeting_name.present?
          fee_detail.update_column(:flex_field_7, meeting_name)
          updated_count += 1
        else
          say "Skipping FeeDetail ID #{fee_detail.id} as its FeeType ('#{fee_detail.fee_type}') has no corresponding meeting_name.",
              true
        end
      end

      say "#{updated_count} FeeDetail records have been updated.", true
    end
  end
end
