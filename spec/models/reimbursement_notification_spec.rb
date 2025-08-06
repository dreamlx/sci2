# spec/models/reimbursement_notification_spec.rb
require 'rails_helper'

RSpec.describe "Reimbursement Unified Notification Status", type: :model do
  let(:admin_user) { create(:admin_user) }
  let(:another_user) { create(:admin_user) }
  
  before do
    # 设置Current.admin_user以满足WorkOrderOperation创建的需要
    Current.admin_user = admin_user
  end
  
  describe "统一通知状态系统" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
    
    describe "#has_unread_updates?" do
      context "当没有任何更新时" do
        it "返回false" do
          expect(reimbursement.has_unread_updates?).to be_falsey
        end
      end
      
      context "当有操作历史记录更新时" do
        before do
          # 创建操作历史记录
          create(:operation_history, 
            document_number: reimbursement.invoice_number,
            operation_type: "审核",
            notes: "审核通过"
          )
          reimbursement.update_notification_status!
        end
        
        it "返回true" do
          expect(reimbursement.has_unread_updates?).to be_truthy
        end
        
        it "has_updates字段为true" do
          expect(reimbursement.has_updates).to be_truthy
        end
        
        it "last_update_at被正确设置" do
          expect(reimbursement.last_update_at).to be_present
        end
      end
      
      context "当有快递工单更新时" do
        before do
          # 创建快递收单工单
          ExpressReceiptWorkOrder.create!(
            reimbursement: reimbursement,
            tracking_number: 'SF1001',
            courier_name: '顺丰',
            received_at: Time.current,
            status: 'completed',
            created_by: admin_user.id
          )
          reimbursement.update_notification_status!
        end
        
        it "返回true" do
          expect(reimbursement.has_unread_updates?).to be_truthy
        end
        
        it "has_updates字段为true" do
          expect(reimbursement.has_updates).to be_truthy
        end
      end
      
      context "当用户已查看更新后" do
        before do
          # 创建更新
          create(:operation_history, 
            document_number: reimbursement.invoice_number,
            operation_type: "审核"
          )
          reimbursement.update_notification_status!
          
          # 标记为已查看
          reimbursement.mark_as_viewed!
        end
        
        it "返回false" do
          expect(reimbursement.has_unread_updates?).to be_falsey
        end
        
        it "has_updates字段为false" do
          expect(reimbursement.has_updates).to be_falsey
        end
        
        it "last_viewed_at被设置" do
          expect(reimbursement.last_viewed_at).to be_present
        end
      end
    end
    
    describe "#update_notification_status!" do
      it "正确计算最新更新时间" do
        # 创建操作历史记录
        operation_time = 2.hours.ago
        create(:operation_history, 
          document_number: reimbursement.invoice_number,
          created_at: operation_time
        )
        
        # 创建快递工单（更晚的时间）
        express_time = 1.hour.ago
        ExpressReceiptWorkOrder.create!(
          reimbursement: reimbursement,
          tracking_number: 'SF1002',
          courier_name: '顺丰',
          received_at: Time.current,
          status: 'completed',
          created_by: admin_user.id,
          created_at: express_time
        )
        
        reimbursement.update_notification_status!
        
        # 应该使用最新的时间
        expect(reimbursement.last_update_at.to_i).to eq(express_time.to_i)
        expect(reimbursement.has_updates).to be_truthy
      end
      
      it "当没有更新时使用updated_at" do
        original_updated_at = reimbursement.updated_at
        reimbursement.update_notification_status!
        
        expect(reimbursement.last_update_at.to_i).to eq(original_updated_at.to_i)
      end
    end
    
    describe "#mark_as_viewed!" do
      before do
        # 创建一些更新
        create(:operation_history, document_number: reimbursement.invoice_number)
        ExpressReceiptWorkOrder.create!(
          reimbursement: reimbursement,
          tracking_number: 'SF1003',
          courier_name: '顺丰',
          received_at: Time.current,
          status: 'completed',
          created_by: admin_user.id
        )
        reimbursement.update_notification_status!
      end
      
      it "正确标记为已查看" do
        expect(reimbursement.has_unread_updates?).to be_truthy
        
        reimbursement.mark_as_viewed!
        
        expect(reimbursement.has_unread_updates?).to be_falsey
        expect(reimbursement.has_updates).to be_falsey
        expect(reimbursement.last_viewed_at).to be_present
      end
      
      it "保持向后兼容性" do
        reimbursement.mark_as_viewed!
        
        expect(reimbursement.last_viewed_operation_histories_at).to be_present
        expect(reimbursement.last_viewed_express_receipts_at).to be_present
      end
    end
  end
  
  describe "查询范围 (Scopes)" do
    let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001') }
    let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002') }
    let!(:reimbursement3) { create(:reimbursement, invoice_number: 'R202501003') }
    
    before do
      # 为reimbursement1创建更新
      create(:operation_history, document_number: reimbursement1.invoice_number)
      reimbursement1.update_notification_status!
      
      # 为reimbursement2创建更新并标记为已查看
      ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement2,
        tracking_number: 'SF1004',
        courier_name: '顺丰',
        received_at: Time.current,
        status: 'completed',
        created_by: admin_user.id
      )
      reimbursement2.update_notification_status!
      reimbursement2.mark_as_viewed!
      
      # reimbursement3没有更新
    end
    
    describe ".with_unread_updates" do
      it "只返回有未读更新的报销单" do
        results = Reimbursement.with_unread_updates
        expect(results).to include(reimbursement1)
        expect(results).not_to include(reimbursement2)
        expect(results).not_to include(reimbursement3)
      end
    end
    
    describe ".ordered_by_notification_status" do
      it "按通知状态排序（有更新的优先）" do
        results = Reimbursement.ordered_by_notification_status
        
        # 有未读更新的应该排在前面
        expect(results.first).to eq(reimbursement1)
      end
    end
  end
  
  describe "用户分配和过滤" do
    let!(:user1_reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
    let!(:user2_reimbursement) { create(:reimbursement, invoice_number: 'R202501002') }
    let!(:unassigned_reimbursement) { create(:reimbursement, invoice_number: 'R202501003') }
    
    before do
      # 分配报销单给不同用户
      create(:reimbursement_assignment, 
        reimbursement: user1_reimbursement, 
        assignee: admin_user, 
        is_active: true
      )
      create(:reimbursement_assignment, 
        reimbursement: user2_reimbursement, 
        assignee: another_user, 
        is_active: true
      )
      
      # 为所有报销单创建更新
      [user1_reimbursement, user2_reimbursement, unassigned_reimbursement].each do |r|
        create(:operation_history, document_number: r.invoice_number)
        r.update_notification_status!
      end
    end
    
    describe ".assigned_with_unread_updates" do
      it "只返回分配给指定用户且有未读更新的报销单" do
        results = Reimbursement.assigned_with_unread_updates(admin_user.id)
        
        expect(results).to include(user1_reimbursement)
        expect(results).not_to include(user2_reimbursement)
        expect(results).not_to include(unassigned_reimbursement)
      end
      
      it "为不同用户返回不同结果" do
        user1_results = Reimbursement.assigned_with_unread_updates(admin_user.id)
        user2_results = Reimbursement.assigned_with_unread_updates(another_user.id)
        
        expect(user1_results).to include(user1_reimbursement)
        expect(user1_results).not_to include(user2_reimbursement)
        
        expect(user2_results).to include(user2_reimbursement)
        expect(user2_results).not_to include(user1_reimbursement)
      end
    end
  end
  
  describe "自动回调触发" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
    
    describe "操作历史记录回调" do
      it "创建操作历史记录时自动更新通知状态" do
        expect(reimbursement.has_unread_updates?).to be_falsey
        
        # 创建操作历史记录应该触发回调
        create(:operation_history, document_number: reimbursement.invoice_number)
        
        reimbursement.reload
        expect(reimbursement.has_unread_updates?).to be_truthy
      end
    end
    
    describe "快递工单回调" do
      it "创建快递工单时自动更新通知状态" do
        expect(reimbursement.has_unread_updates?).to be_falsey
        
        # 创建快递工单应该触发回调
        ExpressReceiptWorkOrder.create!(
          reimbursement: reimbursement,
          tracking_number: 'SF1005',
          courier_name: '顺丰',
          received_at: Time.current,
          status: 'completed',
          created_by: admin_user.id
        )
        
        reimbursement.reload
        expect(reimbursement.has_unread_updates?).to be_truthy
      end
    end
  end
  
  describe "向后兼容性" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
    
    it "旧方法仍然可用" do
      # 创建操作历史记录
      create(:operation_history, document_number: reimbursement.invoice_number)
      
      # 旧方法应该仍然工作
      expect(reimbursement.has_unviewed_operation_histories?).to be_truthy
      expect(reimbursement.has_unviewed_records?).to be_truthy
      
      # 旧的标记方法应该仍然工作
      reimbursement.mark_operation_histories_as_viewed!
      expect(reimbursement.has_unviewed_operation_histories?).to be_falsey
    end
    
    it "新旧方法可以协同工作" do
      create(:operation_history, document_number: reimbursement.invoice_number)
      reimbursement.update_notification_status!
      
      # 使用新方法标记为已查看
      reimbursement.mark_as_viewed!
      
      # 旧方法也应该反映已查看状态
      expect(reimbursement.has_unviewed_operation_histories?).to be_falsey
      expect(reimbursement.has_unviewed_records?).to be_falsey
    end
  end
end