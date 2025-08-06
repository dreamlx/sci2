# spec/integration/reimbursement_notification_integration_spec.rb
require 'rails_helper'

RSpec.describe "Reimbursement Notification Integration", type: :integration do
  let(:admin_user) { create(:admin_user, email: 'admin@test.com') }
  let(:finance_user) { create(:admin_user, email: 'finance@test.com') }
  
  before do
    Current.admin_user = admin_user
  end
  
  describe "完整业务流程模拟" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
    
    before do
      # 分配报销单给财务用户
      create(:reimbursement_assignment, 
        reimbursement: reimbursement, 
        assignee: finance_user, 
        is_active: true
      )
    end
    
    it "完整流程：导入操作历史 → 创建快递工单 → 用户查看 → 状态变化" do
      # === 步骤1: 初始状态验证 ===
      expect(reimbursement.has_unread_updates?).to be_falsey
      expect(Reimbursement.with_unread_updates.count).to eq(0)
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id).count).to eq(0)
      
      # === 步骤2: 导入操作历史记录 ===
      puts "📝 步骤2: 导入操作历史记录"
      
      operation_history = create(:operation_history, 
        document_number: reimbursement.invoice_number,
        operation_type: "提交",
        operator: "张三",
        notes: "提交报销申请",
        operation_time: Time.current
      )
      
      # 验证操作历史记录创建成功
      expect(reimbursement.operation_histories.count).to eq(1)
      
      # 验证自动回调触发通知更新
      reimbursement.reload
      expect(reimbursement.has_unread_updates?).to be_truthy
      expect(reimbursement.has_updates).to be_truthy
      expect(reimbursement.last_update_at).to be_present
      
      # 验证查询范围正确工作
      expect(Reimbursement.with_unread_updates).to include(reimbursement)
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).to include(reimbursement)
      
      # === 步骤3: 创建快递工单 ===
      puts "📦 步骤3: 创建快递工单"
      
      express_work_order = ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement,
        tracking_number: 'SF1001',
        courier_name: '顺丰快递',
        received_at: Time.current,
        status: 'completed',
        created_by: admin_user.id
      )
      
      # 验证快递工单创建成功
      expect(reimbursement.express_receipt_work_orders.count).to eq(1)
      
      # 验证通知状态更新（应该使用最新的更新时间）
      reimbursement.reload
      expect(reimbursement.has_unread_updates?).to be_truthy
      expect(reimbursement.last_update_at).to be >= express_work_order.created_at
      
      # === 步骤4: 模拟用户查看事件 ===
      puts "👀 步骤4: 模拟用户查看事件"
      
      # 财务用户查看报销单
      Current.admin_user = finance_user
      
      # 验证用户可以看到通知
      user_notifications = Reimbursement.assigned_with_unread_updates(finance_user.id)
      expect(user_notifications).to include(reimbursement)
      
      # 用户查看后标记为已读
      reimbursement.mark_as_viewed!
      
      # === 步骤5: 验证状态变化 ===
      puts "✅ 步骤5: 验证状态变化"
      
      # 验证通知状态已清除
      expect(reimbursement.has_unread_updates?).to be_falsey
      expect(reimbursement.has_updates).to be_falsey
      expect(reimbursement.last_viewed_at).to be_present
      
      # 验证查询范围不再包含此报销单
      expect(Reimbursement.with_unread_updates).not_to include(reimbursement)
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).not_to include(reimbursement)
      
      # === 步骤6: 再次更新验证 ===
      puts "🔄 步骤6: 再次更新验证"
      
      # 创建新的操作历史记录
      create(:operation_history, 
        document_number: reimbursement.invoice_number,
        operation_type: "审核",
        operator: "李四",
        notes: "审核通过",
        operation_time: Time.current
      )
      
      # 验证通知状态重新激活
      reimbursement.reload
      expect(reimbursement.has_unread_updates?).to be_truthy
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).to include(reimbursement)
      
      puts "✨ 完整业务流程测试通过！"
    end
  end
  
  describe "多用户协作场景" do
    let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001') }
    let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002') }
    let!(:reimbursement3) { create(:reimbursement, invoice_number: 'R202501003') }
    
    before do
      # 分配报销单给不同用户
      create(:reimbursement_assignment, reimbursement: reimbursement1, assignee: admin_user, is_active: true)
      create(:reimbursement_assignment, reimbursement: reimbursement2, assignee: finance_user, is_active: true)
      # reimbursement3 未分配
    end
    
    it "不同用户只能看到分配给自己的通知" do
      # 为所有报销单创建更新
      [reimbursement1, reimbursement2, reimbursement3].each_with_index do |r, index|
        create(:operation_history, 
          document_number: r.invoice_number,
          operation_type: "审核",
          operator: "用户#{index + 1}"
        )
        r.reload
      end
      
      # 验证admin_user只能看到分配给自己的通知
      admin_notifications = Reimbursement.assigned_with_unread_updates(admin_user.id)
      expect(admin_notifications).to include(reimbursement1)
      expect(admin_notifications).not_to include(reimbursement2)
      expect(admin_notifications).not_to include(reimbursement3)
      
      # 验证finance_user只能看到分配给自己的通知
      finance_notifications = Reimbursement.assigned_with_unread_updates(finance_user.id)
      expect(finance_notifications).to include(reimbursement2)
      expect(finance_notifications).not_to include(reimbursement1)
      expect(finance_notifications).not_to include(reimbursement3)
      
      # 验证未分配的报销单不会出现在任何用户的通知中
      expect(Reimbursement.assigned_with_unread_updates(admin_user.id)).not_to include(reimbursement3)
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).not_to include(reimbursement3)
    end
    
    it "用户查看操作相互独立" do
      # 为两个报销单创建更新
      create(:operation_history, document_number: reimbursement1.invoice_number)
      create(:operation_history, document_number: reimbursement2.invoice_number)
      [reimbursement1, reimbursement2].each(&:reload)
      
      # admin_user查看自己的报销单
      Current.admin_user = admin_user
      reimbursement1.mark_as_viewed!
      
      # 验证admin_user的通知被清除
      expect(Reimbursement.assigned_with_unread_updates(admin_user.id)).not_to include(reimbursement1)
      
      # 验证finance_user的通知不受影响
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).to include(reimbursement2)
      
      # finance_user查看自己的报销单
      Current.admin_user = finance_user
      reimbursement2.mark_as_viewed!
      
      # 验证finance_user的通知也被清除
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).not_to include(reimbursement2)
    end
  end
  
  describe "排序功能测试" do
    let!(:old_reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
    let!(:new_reimbursement) { create(:reimbursement, invoice_number: 'R202501002') }
    let!(:no_update_reimbursement) { create(:reimbursement, invoice_number: 'R202501003') }
    
    it "按通知状态和更新时间正确排序" do
      # 为旧报销单创建较早的更新
      create(:operation_history, 
        document_number: old_reimbursement.invoice_number,
        created_at: 2.hours.ago
      )
      old_reimbursement.reload
      
      # 为新报销单创建较晚的更新
      create(:operation_history, 
        document_number: new_reimbursement.invoice_number,
        created_at: 1.hour.ago
      )
      new_reimbursement.reload
      
      # 使用排序scope
      sorted_results = Reimbursement.ordered_by_notification_status
      
      # 有更新的应该排在前面，且按更新时间倒序
      has_updates = sorted_results.select(&:has_updates)
      expect(has_updates.first).to eq(new_reimbursement)  # 最新更新的排第一
      expect(has_updates.second).to eq(old_reimbursement) # 较早更新的排第二
      
      # 没有更新的排在最后
      expect(sorted_results.last).to eq(no_update_reimbursement)
    end
  end
  
  describe "数据导入场景模拟" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
    
    before do
      create(:reimbursement_assignment, reimbursement: reimbursement, assignee: finance_user, is_active: true)
    end
    
    it "批量导入操作历史记录触发通知" do
      # 模拟批量导入多条操作历史记录
      operation_data = [
        { operation_type: "提交", operator: "张三", notes: "提交申请" },
        { operation_type: "审核", operator: "李四", notes: "部门审核通过" },
        { operation_type: "审批", operator: "王五", notes: "财务审批通过" }
      ]
      
      # 批量创建操作历史记录
      operation_data.each_with_index do |data, index|
        create(:operation_history, 
          document_number: reimbursement.invoice_number,
          operation_type: data[:operation_type],
          operator: data[:operator],
          notes: data[:notes],
          created_at: Time.current + index.minutes
        )
      end
      
      # 验证通知状态正确更新
      reimbursement.reload
      expect(reimbursement.has_unread_updates?).to be_truthy
      expect(reimbursement.operation_histories.count).to eq(3)
      
      # 验证使用最新的操作时间
      latest_operation_time = reimbursement.operation_histories.maximum(:created_at)
      expect(reimbursement.last_update_at.to_i).to eq(latest_operation_time.to_i)
      
      # 验证用户可以看到通知
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).to include(reimbursement)
    end
    
    it "快递工单导入触发通知" do
      # 模拟导入多个快递工单
      express_data = [
        { tracking_number: 'SF1001', courier_name: '顺丰' },
        { tracking_number: 'YTO2001', courier_name: '圆通' },
        { tracking_number: 'ZTO3001', courier_name: '中通' }
      ]
      
      express_data.each_with_index do |data, index|
        ExpressReceiptWorkOrder.create!(
          reimbursement: reimbursement,
          tracking_number: data[:tracking_number],
          courier_name: data[:courier_name],
          received_at: Time.current,
          status: 'completed',
          created_by: admin_user.id,
          created_at: Time.current + index.minutes
        )
      end
      
      # 验证通知状态正确更新
      reimbursement.reload
      expect(reimbursement.has_unread_updates?).to be_truthy
      expect(reimbursement.express_receipt_work_orders.count).to eq(3)
      
      # 验证用户可以看到通知
      expect(Reimbursement.assigned_with_unread_updates(finance_user.id)).to include(reimbursement)
    end
  end
  
  describe "边界情况测试" do
    let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
    
    it "处理同时有操作历史和快递工单的情况" do
      # 创建操作历史记录（较早时间）
      operation_time = 2.hours.ago
      create(:operation_history, 
        document_number: reimbursement.invoice_number,
        created_at: operation_time
      )
      
      # 创建快递工单（较晚时间）
      express_time = 1.hour.ago
      ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement,
        tracking_number: 'SF2001',
        courier_name: '顺丰',
        received_at: Time.current,
        status: 'completed',
        created_by: admin_user.id,
        created_at: express_time
      )
      
      reimbursement.reload
      
      # 应该使用最新的时间（快递工单时间）
      expect(reimbursement.last_update_at.to_i).to eq(express_time.to_i)
      expect(reimbursement.has_unread_updates?).to be_truthy
    end
    
    it "处理重复查看的情况" do
      create(:operation_history, document_number: reimbursement.invoice_number)
      reimbursement.reload
      
      # 第一次查看
      reimbursement.mark_as_viewed!
      first_viewed_time = reimbursement.last_viewed_at
      
      # 等待一秒后再次查看
      sleep(1)
      reimbursement.mark_as_viewed!
      second_viewed_time = reimbursement.last_viewed_at
      
      # 查看时间应该更新
      expect(second_viewed_time).to be > first_viewed_time
      expect(reimbursement.has_unread_updates?).to be_falsey
    end
    
    it "处理删除关联记录的情况" do
      operation = create(:operation_history, document_number: reimbursement.invoice_number)
      reimbursement.reload
      expect(reimbursement.has_unread_updates?).to be_truthy
      
      # 删除操作历史记录
      operation.destroy
      
      # 重新计算通知状态
      reimbursement.update_notification_status!
      
      # 应该没有未读更新了
      expect(reimbursement.has_unread_updates?).to be_falsey
    end
  end
end