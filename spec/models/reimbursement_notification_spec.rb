# spec/models/reimbursement_notification_spec.rb
require 'rails_helper'

RSpec.describe "Reimbursement Notification Status", type: :model do
  let(:admin_user) { create(:admin_user) }
  
  describe "express receipt notifications" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
    
    it "shows notification for new express receipts" do
      # 首先标记所有记录为已查看，确保初始状态干净
      reimbursement.mark_all_as_viewed!
      reimbursement.reload
      
      # 初始状态应该没有未查看的记录
      expect(reimbursement.has_unviewed_express_receipts?).to be_falsey
      
      # 设置Current.admin_user以满足WorkOrderOperation创建的需要
      Current.admin_user = admin_user
      
      # 直接创建快递收单工单，不使用工厂
      express_receipt = ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement,
        tracking_number: 'SF1001',
        courier_name: '顺丰',
        received_at: Time.current,
        status: 'completed',
        created_by: admin_user.id
      )
      
      # 重新加载报销单
      reimbursement.reload
      
      # 验证现在应该有未查看的快递收单
      expect(reimbursement.has_unviewed_express_receipts?).to be_truthy
      
      # 标记为已查看
      reimbursement.mark_express_receipts_as_viewed!
      
      # 验证现在应该没有未查看的快递收单
      expect(reimbursement.has_unviewed_express_receipts?).to be_falsey
      
      # 再创建一个快递收单工单
      another_receipt = ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement,
        tracking_number: 'SF1002',
        courier_name: '顺丰',
        received_at: Time.current,
        status: 'completed',
        created_by: admin_user.id
      )
      
      # 重新加载报销单
      reimbursement.reload
      
      # 验证应该再次有未查看的快递收单
      expect(reimbursement.has_unviewed_express_receipts?).to be_truthy
    end
    
    it "shows notification when importing express receipts" do
      # 首先标记所有记录为已查看，确保初始状态干净
      reimbursement.mark_all_as_viewed!
      reimbursement.reload
      
      # 初始状态应该没有未查看的记录
      expect(reimbursement.has_unviewed_express_receipts?).to be_falsey
      
      # 设置Current.admin_user以满足WorkOrderOperation创建的需要
      Current.admin_user = admin_user
      
      # 直接使用我们修改过的ExpressReceiptImportService的import_express_receipt方法
      # 这样可以确保我们的修复代码被执行
      service = ExpressReceiptImportService.new(nil, admin_user)
      service.send(:import_express_receipt, {
        '单号' => reimbursement.invoice_number,
        '操作意见' => '快递单号: SF1001',
        '操作时间' => '2025-01-01 10:00:00'
      }, 1)
      
      # 重新加载报销单
      reimbursement.reload
      
      # 验证现在应该有未查看的快递收单
      expect(reimbursement.has_unviewed_express_receipts?).to be_truthy
    end
  end
end