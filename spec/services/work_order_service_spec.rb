require 'rails_helper'

RSpec.describe WorkOrderService, type: :service do
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
  
  let(:fee_type) do
    FeeType.create!(
      code: "00",
      title: "月度交通费",
      meeting_type: "个人",
      active: true
    )
  end
  
  let(:problem_type) do
    ProblemType.create!(
      code: "01",
      title: "燃油费行程问题",
      sop_description: "检查燃油费是否与行程匹配",
      standard_handling: "要求提供详细行程单",
      fee_type: fee_type,
      active: true
    )
  end
  
  # 设置Current.admin_user
  before do
    Current.admin_user = admin_user
  end
  
  # 清理Current.admin_user
  after do
    Current.admin_user = nil
  end
  
  describe "审核工单状态处理" do
    let(:audit_work_order) do
      # 创建工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
        work_order_type: work_order.class.name
      )
      
      work_order
    end
    
    let(:service) { WorkOrderService.new(audit_work_order, admin_user) }
    
    context "处理意见设置为'可以通过'" do
      it "工单状态变更为approved" do
        # 设置处理意见为"可以通过"
        audit_work_order.processing_opinion = '可以通过'
        
        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证结果
        expect(audit_work_order.reload.status).to eq('approved')
      end
      
      it "关联的费用明细状态变更为verified" do
        # 设置处理意见为"可以通过"
        audit_work_order.processing_opinion = '可以通过'
        
        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
      end
    end
    
    context "处理意见设置为'无法通过'" do
      it "工单状态变更为rejected" do
        # 设置处理意见为"无法通过"
        audit_work_order.processing_opinion = '无法通过'
        
        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证结果
        expect(audit_work_order.reload.status).to eq('rejected')
      end
      
      it "关联的费用明细状态变更为problematic" do
        # 设置处理意见为"无法通过"
        audit_work_order.processing_opinion = '无法通过'
        
        # 直接调用方法
        audit_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
      end
    end
  end
  
  describe "沟通工单状态处理" do
    let(:communication_work_order) do
      # 创建工单
      work_order = CommunicationWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
        work_order_type: work_order.class.name
      )
      
      work_order
    end
    
    let(:service) { WorkOrderService.new(communication_work_order, admin_user) }
    
    context "处理意见设置为'可以通过'" do
      it "工单状态变更为approved" do
        # 设置处理意见为"可以通过"
        communication_work_order.processing_opinion = '可以通过'
        
        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证结果
        expect(communication_work_order.reload.status).to eq('approved')
      end
      
      it "关联的费用明细状态变更为verified" do
        # 设置处理意见为"可以通过"
        communication_work_order.processing_opinion = '可以通过'
        
        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
      end
    end
    
    context "处理意见设置为'无法通过'" do
      it "工单状态变更为rejected" do
        # 设置处理意见为"无法通过"
        communication_work_order.processing_opinion = '无法通过'
        
        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证结果
        expect(communication_work_order.reload.status).to eq('rejected')
      end
      
      it "关联的费用明细状态变更为problematic" do
        # 设置处理意见为"无法通过"
        communication_work_order.processing_opinion = '无法通过'
        
        # 直接调用方法
        communication_work_order.send(:set_status_based_on_processing_opinion)
        
        # 验证费用明细状态
        expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
      end
    end
  end
  
  describe "多问题类型处理" do
    let(:another_problem_type) do
      ProblemType.create!(
        code: "02",
        title: "交通费超标",
        sop_description: "检查交通费是否超过标准",
        standard_handling: "要求提供说明",
        fee_type: fee_type,
        active: true
      )
    end
    
    let(:audit_work_order) do
      # 创建工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
        work_order_type: work_order.class.name
      )
      
      work_order
    end
    
    it "支持添加多个问题类型" do
      # 设置多个问题类型
      audit_work_order.problem_type_ids = [problem_type.id, another_problem_type.id]
      
      # 直接调用方法
      audit_work_order.send(:process_problem_types)
      
      # 验证结果
      expect(audit_work_order.problem_types.count).to eq(2)
      expect(audit_work_order.problem_types).to include(problem_type, another_problem_type)
    end
  end
  
  describe "最新工单决定原则" do
    let(:audit_work_order_1) do
      # 创建第一个工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
        work_order_type: work_order.class.name
      )
      
      work_order
    end
    
    let(:audit_work_order_2) do
      # 创建第二个工单
      work_order = AuditWorkOrder.create!(
        reimbursement: reimbursement,
        status: "pending",
        created_by: admin_user.id
      )
      
      # 关联费用明细
      WorkOrderFeeDetail.create!(
        work_order: work_order,
        fee_detail: fee_detail,
        work_order_type: work_order.class.name
      )
      
      work_order
    end
    
    it "费用明细状态由最新工单决定" do
      # 第一个工单设置为拒绝
      audit_work_order_1.update_column(:status, 'rejected')
      audit_work_order_1.sync_fee_details_verification_status
      
      # 验证费用明细状态为problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
      
      # 第二个工单设置为通过
      audit_work_order_2.update_column(:status, 'approved')
      audit_work_order_2.sync_fee_details_verification_status
      
      # 验证费用明细状态变为verified
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_VERIFIED)
      
      # 更新第二个工单的更新时间为更早的时间
      audit_work_order_2.update_column(:updated_at, 1.day.ago)
      
      # 重新触发第一个工单的状态更新
      audit_work_order_1.sync_fee_details_verification_status
      
      # 验证费用明细状态变回problematic
      expect(fee_detail.reload.verification_status).to eq(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC)
    end
  end
end