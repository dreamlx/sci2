require 'rails_helper'

RSpec.describe "Audit Work Order Form", type: :system, js: true do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_type) { create(:fee_type, code: "JKF", title: "会议讲课费", meeting_type: "学术论坛") }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number, fee_type: fee_type.title) }
  let!(:problem_type) { create(:problem_type, code: "FPLC", title: "发票信息不完整", fee_type: fee_type) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "费用明细选择功能" do
    it "选择费用明细后显示费用类型标签" do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
      
      # 确认页面加载完成
      expect(page).to have_content("选择关联的费用明细")
      
      # 选择费用明细
      check("fee_detail_#{fee_detail.id}")
      
      # 等待JavaScript执行
      sleep(0.5)
      
      # 验证费用明细是否被选中
      expect(page).to have_checked_field("fee_detail_#{fee_detail.id}")
      
      # 选择处理意见为"无法通过"
      select "无法通过", from: "audit_work_order_processing_opinion"
      
      # 等待JavaScript执行
      sleep(0.5)
      
      # 验证问题类型区域是否显示
      expect(page).to have_css('.problem-types-container', visible: true)
      
      # 填写审核意见
      fill_in "audit_comment_field", with: "测试审核意见"
      
      # 提交表单
      click_button "提交"
      
      # 验证是否成功创建工单
      expect(page).to have_content("审核工单已成功创建")
    end
  end
  
  describe "完整工作流程" do
    it "可以创建审核工单并设置处理意见" do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
      
      # 选择费用明细
      check("fee_detail_#{fee_detail.id}")
      
      # 选择处理意见为"可以通过"
      select "可以通过", from: "audit_work_order_processing_opinion"
      
      # 填写审核意见
      fill_in "audit_comment_field", with: "审核通过测试"
      
      # 提交表单
      click_button "提交"
      
      # 验证是否成功创建工单
      expect(page).to have_content("审核工单已成功创建")
      expect(page).to have_content("APPROVED")
      expect(page).to have_content("审核通过测试")
    end
    
    it "可以创建审核工单并设置问题类型" do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
      
      # 选择费用明细
      check("fee_detail_#{fee_detail.id}")
      
      # 选择处理意见为"无法通过"
      select "无法通过", from: "audit_work_order_processing_opinion"
      
      # 等待JavaScript执行
      sleep(0.5)
      
      # 填写审核意见
      fill_in "audit_comment_field", with: "审核拒绝测试"
      
      # 提交表单
      click_button "提交"
      
      # 验证是否成功创建工单
      expect(page).to have_content("审核工单已成功创建")
      expect(page).to have_content("REJECTED")
      expect(page).to have_content("审核拒绝测试")
    end
  end
end