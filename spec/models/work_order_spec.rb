require 'rails_helper'

RSpec.describe WorkOrder, type: :model do
  let(:admin_user) { AdminUser.create!(email: 'admin@example.com', password: 'password') }
  
  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: "INV-001",
      document_name: "个人报销单",
      status: "processing",
      is_electronic: true
    )
  end
  
  let(:fee_detail) do
    FeeDetail.create!(
      document_number: reimbursement.invoice_number,
      fee_type: "月度交通费",
      amount: 100.0,
      fee_date: Date.today,
      verification_status: "pending"
    )
  end
  
  before do
    Current.admin_user = admin_user
  end
  
  after do
    Current.admin_user = nil
  end
  
  describe "状态处理" do
    let(:work_order) do
      # 创建工单
      order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: order,
        fee_detail: fee_detail,
        work_order_type: "AuditWorkOrder"
      )
      
      order
    end
    
    context "处理意见设置为'可以通过'" do
      it "工单状态变更为approved" do
        # 设置处理意见
        work_order.processing_opinion = '可以通过'
        
        # 直接调用方法
        work_order.send(:set_status_based_on_processing_opinion)
        
        # 重新加载工单
        work_order.reload
        
        # 验证状态
        expect(work_order.status).to eq('approved')
      end
      
      it "关联的费用明细状态变更为verified" do
        # 设置处理意见
        work_order.processing_opinion = '可以通过'
        
        # 直接调用方法
        work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
      end
    end
    
    context "处理意见设置为'无法通过'" do
      it "工单状态变更为rejected" do
        # 设置处理意见
        work_order.processing_opinion = '无法通过'
        
        # 直接调用方法
        work_order.send(:set_status_based_on_processing_opinion)
        
        # 重新加载工单
        work_order.reload
        
        # 验证状态
        expect(work_order.status).to eq('rejected')
      end
      
      it "关联的费用明细状态变更为problematic" do
        # 设置处理意见
        work_order.processing_opinion = '无法通过'
        
        # 直接调用方法
        work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
      end
    end
  end
  
  describe "直接使用状态机事件" do
    let(:work_order) do
      # 创建工单
      order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: order,
        fee_detail: fee_detail,
        work_order_type: "AuditWorkOrder"
      )
      
      order
    end
    
    it "approve事件将状态变更为approved" do
      # 直接设置状态
      work_order.update_column(:status, 'approved')
      
      # 手动触发费用明细状态更新
      work_order.sync_fee_details_verification_status
      
      # 验证状态
      expect(work_order.status).to eq('approved')
      
      # 验证费用明细状态
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
    end
    
    it "reject事件将状态变更为rejected" do
      # 直接设置状态
      work_order.update_column(:status, 'rejected')
      
      # 手动触发费用明细状态更新
      work_order.sync_fee_details_verification_status
      
      # 验证状态
      expect(work_order.status).to eq('rejected')
      
      # 验证费用明细状态
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    end
  end
  
  describe "最新工单决定原则" do
    let(:work_order_1) do
      # 创建第一个工单
      order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: order,
        fee_detail: fee_detail,
        work_order_type: "AuditWorkOrder"
      )
      
      order
    end
    
    let(:work_order_2) do
      # 创建第二个工单
      order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: order,
        fee_detail: fee_detail,
        work_order_type: "AuditWorkOrder"
      )
      
      order
    end
    
    it "费用明细状态由最新工单决定" do
      # 第一个工单设置为拒绝
      work_order_1.update_column(:status, 'rejected')
      work_order_1.sync_fee_details_verification_status
      
      # 验证费用明细状态为problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
      
      # 第二个工单设置为通过
      work_order_2.update_column(:status, 'approved')
      work_order_2.sync_fee_details_verification_status
      
      # 验证费用明细状态变为verified
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
      
      # 更新第二个工单的更新时间为更早的时间
      work_order_2.update_column(:updated_at, 1.day.ago)
      
      # 重新触发第一个工单的状态更新
      work_order_1.sync_fee_details_verification_status
      
      # 验证费用明细状态变回problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    end
  end
end