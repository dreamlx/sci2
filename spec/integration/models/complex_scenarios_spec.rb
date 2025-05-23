# spec/integration/models/complex_scenarios_spec.rb
require 'rails_helper'

RSpec.describe "Complex Scenarios", type: :model do
  describe "basic reimbursement workflow" do
    let(:reimbursement) { create(:reimbursement) }
    let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
    
    it "can create express receipt work order" do
      # 创建快递收单工单
      express_receipt = create(:express_receipt_work_order,
                             reimbursement: reimbursement,
                             status: 'completed')
      
      # 验证关联
      expect(express_receipt.reimbursement).to eq(reimbursement)
      expect(reimbursement.express_receipt_work_orders).to include(express_receipt)
    end
    
    it "can create audit work order" do
      # 创建审核工单
      # 先构建工单对象
      audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      audit_work_order.save!
      
      # 验证关联
      expect(audit_work_order.reimbursement).to eq(reimbursement)
      expect(reimbursement.audit_work_orders).to include(audit_work_order)
    end
    
    it "can create communication work order" do
      # 创建审核工单
      # 先构建工单对象
      audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      audit_work_order.save!
      
      # 创建沟通工单
      # 先构建工单对象
      communication_work_order = build(:communication_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      communication_work_order.save!
      
      # 验证关联
      expect(communication_work_order.reimbursement).to eq(reimbursement)
      # audit_work_order association has been removed
      expect(reimbursement.communication_work_orders).to include(communication_work_order)
    end
    
    it "can add communication record to communication work order" do
      # 创建审核工单
      # 先构建工单对象
      audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      audit_work_order.save!
      
      # 创建沟通工单
      # 先构建工单对象
      communication_work_order = build(:communication_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      communication_work_order.save!
      
      # 添加沟通记录
      communication_record = create(:communication_record,
                                  communication_work_order: communication_work_order,
                                  content: "已与申请人沟通，问题已解决")
      
      # 验证关联
      expect(communication_work_order.communication_records).to include(communication_record)
      expect(communication_record.communication_work_order).to eq(communication_work_order)
    end
  end
end