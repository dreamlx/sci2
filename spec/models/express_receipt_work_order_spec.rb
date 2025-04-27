# spec/models/express_receipt_work_order_spec.rb
require 'rails_helper'

RSpec.describe ExpressReceiptWorkOrder, type: :model do
  # 验证测试（不依赖其他模型）
  describe "validations" do
    it { should validate_presence_of(:tracking_number) }
    it { should validate_inclusion_of(:status).in_array(['completed']) }
  end
  
  # 初始化回调测试
  describe "callbacks" do
    it "sets default status to completed on create" do
      reimbursement = build_stubbed(:reimbursement)
      work_order = ExpressReceiptWorkOrder.new(reimbursement: reimbursement, tracking_number: "SF1234")
      work_order.valid?
      expect(work_order.status).to eq('completed')
    end
  end
  
  # 业务方法测试
  describe "#mark_reimbursement_as_received" do
    it "calls mark_as_received on reimbursement with received_at" do
      # 创建一个简单的测试对象，避免工厂复杂性
      reimbursement = create(:reimbursement)
      work_order = ExpressReceiptWorkOrder.new(
        reimbursement: reimbursement,
        tracking_number: "SF1234",
        status: "completed"
      )
      
      received_time = Time.current - 1.day
      work_order.received_at = received_time
      
      expect(reimbursement).to receive(:mark_as_received).with(received_time)
      work_order.mark_reimbursement_as_received
    end
    
    it "calls mark_as_received with current time if received_at is nil" do
      # 创建一个简单的测试对象，避免工厂复杂性
      reimbursement = create(:reimbursement)
      work_order = ExpressReceiptWorkOrder.new(
        reimbursement: reimbursement,
        tracking_number: "SF1234",
        status: "completed"
      )
      
      work_order.received_at = nil
      
      # 使用 be_within 匹配当前时间
      expect(reimbursement).to receive(:mark_as_received) do |time|
        expect(time).to be_within(1.second).of(Time.current)
      end
      
      work_order.mark_reimbursement_as_received
    end
  end
  
  # 继承测试
  describe "inheritance" do
    it "inherits from WorkOrder" do
      expect(described_class.superclass).to eq(WorkOrder)
    end
  end
end