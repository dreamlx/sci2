require 'rails_helper'

RSpec.describe "Complete Business Flows", type: :integration do
  let!(:admin_user) { create(:admin_user) }
  
  before do
    Current.admin_user = admin_user
  end
  
  after do
    Current.admin_user = nil
  end

  describe "INT-001: 完整报销流程-快递收单到审核完成" do
    let!(:reimbursement) { create(:reimbursement) }
    let!(:fee_details) { create_list(:fee_detail, 3, document_number: reimbursement.invoice_number) }
    
    it "completes the full workflow from express receipt to audit approval" do
      # 1. 导入快递收单，创建ExpressReceiptWorkOrder
      # 创建快递收单工单应该自动触发报销单状态更新为processing
      express_work_order = create(:express_receipt_work_order, reimbursement: reimbursement)
      
      # 验证报销单状态已更新
      reimbursement.reload
      expect(reimbursement.status).to eq('processing')
      
      # 2. 创建审核工单
      # 先构建工单对象
      audit_work_order = build(:audit_work_order,
                              reimbursement: reimbursement,
                              problem_type: "发票问题",
                              problem_description: "发票信息不完整",
                              remark: "需要补充完整的发票信息",
                              processing_opinion: "需要补充材料")
      
      # 设置fee_detail_ids_to_select
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', fee_details.map(&:id))
      
      # 保存工单
      audit_work_order.save!
      
      # 处理费用明细关联
      audit_work_order.process_fee_detail_selections
      
      # 4. 开始处理审核工单
      audit_service = AuditWorkOrderService.new(audit_work_order, admin_user)
      audit_service.start_processing
      
      # 验证费用明细状态变为problematic
      # 工单状态变更应该自动触发费用明细状态更新
      fee_details.each do |fd|
        fd.reload
        expect(fd.verification_status).to eq('problematic')
      end
      
      # 5. 审核通过
      audit_service.approve({
        audit_comment: "已补充完整发票信息，审核通过",
        vat_verified: true
      })
      
      # 验证费用明细状态变为verified
      # 工单状态变更应该自动触发费用明细状态更新
      fee_details.each do |fd|
        fd.reload
        expect(fd.verification_status).to eq('verified')
      end
      
      # 验证所有费用明细已验证
      reimbursement.reload
      expect(reimbursement.all_fee_details_verified?).to be true
      
      # 验证可以将报销单标记为close
      expect(reimbursement.can_mark_as_close?).to be true
      
      # 模拟用户点击"处理完成"按钮
      reimbursement.mark_as_close!
      expect(reimbursement.reload.status).to eq('close')
      
      # 验证审核工单状态变为approved
      audit_work_order.reload
      expect(audit_work_order.status).to eq('approved')
      expect(audit_work_order.audit_result).to eq('approved')
    end
  end

  describe "INT-002: 完整报销流程-包含沟通处理" do
    let!(:reimbursement) { create(:reimbursement) }
    let!(:fee_details) { create_list(:fee_detail, 3, document_number: reimbursement.invoice_number) }
    
    it "completes the full workflow including communication" do
      # 1. 导入快递收单，创建ExpressReceiptWorkOrder
      # 创建快递收单工单应该自动触发报销单状态更新为processing
      express_work_order = create(:express_receipt_work_order, reimbursement: reimbursement)
      
      # 验证报销单状态已更新
      reimbursement.reload
      expect(reimbursement.status).to eq('processing')
      
      # 2. 创建审核工单
      # 先构建工单对象
      audit_work_order = build(:audit_work_order,
                              reimbursement: reimbursement,
                              problem_type: "金额错误",
                              problem_description: "发票金额与申报金额不符",
                              remark: "需要核实金额",
                              processing_opinion: "需要修改申报信息")
      
      # 设置fee_detail_ids_to_select
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', fee_details.map(&:id))
      
      # 保存工单
      audit_work_order.save!
      
      # 处理费用明细关联
      audit_work_order.process_fee_detail_selections
      
      # 3. 开始处理审核工单
      audit_service = AuditWorkOrderService.new(audit_work_order, admin_user)
      audit_service.start_processing
      
      # 验证费用明细状态变为problematic
      # 工单状态变更应该自动触发费用明细状态更新
      fee_details.each do |fd|
        fd.reload
        expect(fd.verification_status).to eq('problematic')
      end
      
      # 4. 审核拒绝
      audit_service.reject({
        audit_comment: "金额不符，需要沟通确认"
      })
      
      # 验证审核工单状态变为rejected
      audit_work_order.reload
      expect(audit_work_order.status).to eq('rejected')
      expect(audit_work_order.audit_result).to eq('rejected')
      
      # 5. 创建沟通工单
      # 先构建工单对象
      communication_work_order = build(:communication_work_order,
                                      reimbursement: reimbursement,
                                      problem_type: "金额错误",
                                      problem_description: "发票金额与申报金额不符",
                                      remark: "需要与申请人沟通",
                                      processing_opinion: "需要修改申报信息",
                                      communication_method: "电话",
                                      initiator_role: "财务人员")
      
      # 设置fee_detail_ids_to_select
      communication_work_order.instance_variable_set('@fee_detail_ids_to_select', fee_details.map(&:id))
      
      # 保存工单
      communication_work_order.save!
      
      # 处理费用明细关联
      communication_work_order.process_fee_detail_selections
      
      # 6. 标记需要沟通
      comm_service = CommunicationWorkOrderService.new(communication_work_order, admin_user)
      comm_service.toggle_needs_communication(true)
      
      # 验证沟通工单needs_communication标志设置为true
      communication_work_order.reload
      expect(communication_work_order.needs_communication).to be true
      # 状态应该保持不变，因为needs_communication是布尔标志而非状态
      expect(communication_work_order.status).to eq('pending')
      
      # 7. 添加沟通记录
      comm_record = communication_work_order.add_communication_record({
        content: "已与申请人沟通，确认金额应为1000元",
        communicator_role: "财务人员",
        communicator_name: "财务小王",
        communication_method: "电话",
        recorded_at: Time.current
      })
      
      expect(comm_record).to be_persisted
      
      # 8. 沟通后通过
      comm_service.approve({
        resolution_summary: "已与申请人确认金额，问题已解决"
      })
      
      # 验证沟通工单状态变为approved
      communication_work_order.reload
      expect(communication_work_order.status).to eq('approved')
      
      # 验证费用明细状态变为verified
      # 工单状态变更应该自动触发费用明细状态更新
      fee_details.each do |fd|
        fd.reload
        expect(fd.verification_status).to eq('verified')
      end
      
      # 验证所有费用明细已验证
      reimbursement.reload
      expect(reimbursement.all_fee_details_verified?).to be true
      
      # 验证可以将报销单标记为close
      expect(reimbursement.can_mark_as_close?).to be true
      
      # 模拟用户点击"处理完成"按钮
      reimbursement.mark_as_close!
      expect(reimbursement.reload.status).to eq('close')
    end
  end

  describe "INT-004: 费用明细多工单关联测试" do
    let!(:reimbursement) { create(:reimbursement) }
    let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
    
    it "handles fee details associated with multiple work orders" do
      # 1. 创建审核工单，关联费用明细
      # 先构建工单对象
      audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      audit_work_order.save!
      
      # 处理费用明细关联
      audit_work_order.process_fee_detail_selections
      
      # 2. 创建沟通工单，关联相同费用明细
      # 先构建工单对象
      communication_work_order = build(:communication_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      communication_work_order.save!
      
      # 处理费用明细关联
      communication_work_order.process_fee_detail_selections
      
      # 3. 处理审核工单，拒绝
      audit_service = AuditWorkOrderService.new(audit_work_order, admin_user)
      audit_service.start_processing
      audit_service.reject({audit_comment: "需要沟通"})
      
      # 验证费用明细状态为problematic
      # 工单状态变更应该自动触发费用明细状态更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
      
      # 4. 处理沟通工单，通过
      comm_service = CommunicationWorkOrderService.new(communication_work_order, admin_user)
      comm_service.mark_needs_communication
      comm_service.approve({resolution_summary: "已沟通解决"})
      
      # 验证费用明细状态变为verified（最新处理的工单状态）
      # 工单状态变更应该自动触发费用明细状态更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
      
      # 5. 验证费用明细关联了两个工单
      expect(fee_detail.work_orders.count).to eq(2)
      expect(fee_detail.work_orders).to include(audit_work_order)
      expect(fee_detail.work_orders).to include(communication_work_order)
    end
  end

  describe "INT-005: 操作历史影响报销单状态" do
    let!(:reimbursement) { create(:reimbursement, status: 'processing') }
    
    it "updates reimbursement status based on operation history" do
      # 创建操作历史记录，应该自动触发报销单状态更新
      operation_history = OperationHistory.create!(
        document_number: reimbursement.invoice_number,
        operation_type: "审批",
        operation_time: Time.current,
        operator: "审批人",
        notes: "审批通过"
      )
      
      # 验证报销单状态变为close
      reimbursement.reload
      expect(reimbursement.status).to eq('close')
      
      # 验证操作历史记录已创建
      expect(operation_history).to be_persisted
      expect(operation_history.operation_type).to eq("审批")
      expect(operation_history.notes).to eq("审批通过")
    end
  end

  describe "INT-006: 电子发票标志测试" do
    it "handles electronic invoice flag" do
      # 创建电子发票报销单
      reimbursement = create(:reimbursement, is_electronic: true)
      expect(reimbursement.is_electronic).to be true
      
      # 创建非电子发票报销单
      non_electronic = create(:reimbursement, is_electronic: false)
      expect(non_electronic.is_electronic).to be false
      
      # 验证scope
      expect(Reimbursement.electronic).to include(reimbursement)
      expect(Reimbursement.electronic).not_to include(non_electronic)
      expect(Reimbursement.non_electronic).to include(non_electronic)
      expect(Reimbursement.non_electronic).not_to include(reimbursement)
    end
  end
end