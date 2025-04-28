# spec/models/communication_work_order_spec.rb
require 'rails_helper'

RSpec.describe CommunicationWorkOrder, type: :model do
  # 验证测试（不依赖其他模型）
  describe "validations" do
    it { should validate_inclusion_of(:status).in_array(%w[pending processing needs_communication approved rejected]) }
    
    context "when approved or rejected" do
      before do
        allow(subject).to receive(:approved?).and_return(true)
      end
      
      it { should validate_presence_of(:resolution_summary) }
    end
    
    context "when rejected" do
      before do
        allow(subject).to receive(:rejected?).and_return(true)
      end
      
      it { should validate_presence_of(:problem_type) }
    end
  end
  
  # 关联方法测试（使用 respond_to 而不是实际测试关联）
  describe "association methods" do
    it { should respond_to(:communication_records) }
  end

  # 状态机测试
  describe "state machine" do
    let(:reimbursement) { build_stubbed(:reimbursement) }
    let(:work_order) do
      build(:communication_work_order).tap do |wo|
        # 使用 stub 绕过验证
        allow(wo).to receive(:reimbursement).and_return(reimbursement)
        allow(wo).to receive(:valid?).and_return(true)
        allow(wo).to receive(:update_associated_fee_details_status)
        # 禁用回调以避免数据库访问
        allow(wo).to receive(:update_reimbursement_status_on_create)
        allow(wo).to receive(:record_status_change)
      end
    end
    
    context "when in pending state" do
      it "can transition to processing" do
        expect(work_order.status).to eq("pending")
        expect(work_order.start_processing!).to be_truthy
        expect(work_order.status).to eq("processing")
        
        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('problematic')
      end
      
      it "can transition to needs_communication" do
        expect(work_order.mark_needs_communication!).to be_truthy
        expect(work_order.status).to eq("needs_communication")
        
        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('problematic')
      end
    end
    
    context "when in processing state" do
      let(:work_order) do
        build(:communication_work_order, :processing).tap do |wo|
          # 使用 stub 绕过验证
          allow(wo).to receive(:reimbursement).and_return(reimbursement)
          allow(wo).to receive(:valid?).and_return(true)
          allow(wo).to receive(:update_associated_fee_details_status)
          # 禁用回调以避免数据库访问
          allow(wo).to receive(:update_reimbursement_status_on_create)
          allow(wo).to receive(:record_status_change)
          # 为 approved/rejected 状态添加必要的字段
          allow(wo).to receive(:resolution_summary).and_return("测试解决方案")
          allow(wo).to receive(:problem_type).and_return("documentation_issue")
        end
      end
      
      it "can transition to approved" do
        expect(work_order.approve!).to be_truthy
        expect(work_order.status).to eq("approved")
        
        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('verified')
      end
      
      it "can transition to rejected" do
        expect(work_order.reject!).to be_truthy
        expect(work_order.status).to eq("rejected")
        
        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('problematic')
      end
    end
    
    context "when in needs_communication state" do
      let(:work_order) do
        build(:communication_work_order, :needs_communication).tap do |wo|
          # 使用 stub 绕过验证
          allow(wo).to receive(:reimbursement).and_return(reimbursement)
          allow(wo).to receive(:valid?).and_return(true)
          allow(wo).to receive(:update_associated_fee_details_status)
          # 禁用回调以避免数据库访问
          allow(wo).to receive(:update_reimbursement_status_on_create)
          allow(wo).to receive(:record_status_change)
          # 为 approved/rejected 状态添加必要的字段
          allow(wo).to receive(:resolution_summary).and_return("测试解决方案")
          allow(wo).to receive(:problem_type).and_return("documentation_issue")
        end
      end
      
      it "can transition to approved" do
        expect(work_order.approve!).to be_truthy
        expect(work_order.status).to eq("approved")
        
        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('verified')
      end
      
      it "can transition to rejected" do
        expect(work_order.reject!).to be_truthy
        expect(work_order.status).to eq("rejected")
        
        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('problematic')
      end
    end
  end
  
  # 费用明细选择方法测试
  describe "#select_fee_detail" do
    let(:reimbursement) { build_stubbed(:reimbursement, invoice_number: "R123456") }
    let(:work_order) { build_stubbed(:communication_work_order, reimbursement: reimbursement) }
    let(:fee_detail) { build_stubbed(:fee_detail, document_number: "R123456", verification_status: 'pending') }
    let(:fee_detail_selection) { build_stubbed(:fee_detail_selection) }
    
    it "creates a new fee detail selection" do
      # 使用 stub 模拟 fee_detail_selections 关联
      allow(work_order).to receive_message_chain(:fee_detail_selections, :find_or_create_by!).and_return(fee_detail_selection)
      
      result = work_order.select_fee_detail(fee_detail)
      expect(result).to eq(fee_detail_selection)
    end
    
    it "returns nil if fee detail doesn't belong to the same reimbursement" do
      other_fee_detail = build_stubbed(:fee_detail, document_number: "R999999")
      result = work_order.select_fee_detail(other_fee_detail)
      expect(result).to be_nil
    end
  end
  
  # 沟通记录方法测试
  describe "#add_communication_record" do
    let(:work_order) { build_stubbed(:communication_work_order, id: 123) }
    let(:communication_record) { build_stubbed(:communication_record) }
    let(:params) { { content: "测试沟通内容", communicator_role: "审核人" } }
    
    it "creates a new communication record" do
      # 使用 stub 模拟 communication_records 关联
      allow(work_order).to receive_message_chain(:communication_records, :create).and_return(communication_record)
      
      result = work_order.add_communication_record(params)
      
      # 验证调用了 create 方法并传递了正确的参数
      expect(work_order.communication_records).to have_received(:create).with(
        hash_including(
          content: "测试沟通内容",
          communicator_role: "审核人",
          communication_work_order_id: 123
        )
      )
      
      expect(result).to eq(communication_record)
    end
  end
  
  # 状态检查方法测试
  describe "state check methods" do
    it "returns true for pending? when status is pending" do
      work_order = build(:communication_work_order, status: 'pending')
      expect(work_order.pending?).to be_truthy
    end
    
    it "returns true for processing? when status is processing" do
      work_order = build(:communication_work_order, status: 'processing')
      expect(work_order.processing?).to be_truthy
    end
    
    it "returns true for needs_communication? when status is needs_communication" do
      work_order = build(:communication_work_order, status: 'needs_communication')
      expect(work_order.needs_communication?).to be_truthy
    end
    
    it "returns true for approved? when status is approved" do
      work_order = build(:communication_work_order, status: 'approved')
      expect(work_order.approved?).to be_truthy
    end
    
    it "returns true for rejected? when status is rejected" do
      work_order = build(:communication_work_order, status: 'rejected')
      expect(work_order.rejected?).to be_truthy
    end
  end
end