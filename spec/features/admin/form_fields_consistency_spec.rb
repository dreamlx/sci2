require 'rails_helper'

RSpec.describe "表单字段一致性", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "审核工单和沟通工单表单字段一致性" do
    it "审核工单和沟通工单共享相同的问题类型选项" do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
      audit_problem_types = find("#audit_work_order_problem_type").all("option").map(&:text)
      
      visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id)
      communication_problem_types = find("#communication_work_order_problem_type").all("option").map(&:text)
      
      expect(audit_problem_types).to eq(communication_problem_types)
    end
    
    it "审核工单和沟通工单共享相同的问题说明选项" do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
      audit_problem_descriptions = find("#audit_work_order_problem_description").all("option").map(&:text)
      
      visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id)
      communication_problem_descriptions = find("#communication_work_order_problem_description").all("option").map(&:text)
      
      expect(audit_problem_descriptions).to eq(communication_problem_descriptions)
    end
    
    it "审核工单和沟通工单共享相同的处理意见选项" do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
      audit_processing_opinions = find("#audit_work_order_processing_opinion").all("option").map(&:text)
      
      visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id)
      communication_processing_opinions = find("#communication_work_order_processing_opinion").all("option").map(&:text)
      
      expect(audit_processing_opinions).to eq(communication_processing_opinions)
    end
  end
  
  describe "状态字段只读性" do
    let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }
    let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'pending') }
    
    it "审核工单编辑页面状态字段为只读" do
      visit edit_admin_audit_work_order_path(audit_work_order)
      expect(page).not_to have_select("audit_work_order[status]")
      expect(page).to have_content("状态")
      expect(page).to have_content("pending")
    end
    
    it "沟通工单编辑页面状态字段为只读" do
      visit edit_admin_communication_work_order_path(communication_work_order)
      expect(page).not_to have_select("communication_work_order[status]")
      expect(page).to have_content("状态")
      expect(page).to have_content("pending")
    end
  end
  
  describe "处理意见与状态关系" do
    let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }
    
    it "处理意见为'可以通过'时，状态变为approved" do
      visit edit_admin_audit_work_order_path(audit_work_order)
      select "可以通过", from: "audit_work_order[processing_opinion]"
      click_button "更新审核工单"
      
      visit admin_audit_work_order_path(audit_work_order)
      expect(page).to have_content("approved")
    end
    
    it "处理意见为'无法通过'时，状态变为rejected" do
      visit edit_admin_audit_work_order_path(audit_work_order)
      select "无法通过", from: "audit_work_order[processing_opinion]"
      click_button "更新审核工单"
      
      visit admin_audit_work_order_path(audit_work_order)
      expect(page).to have_content("rejected")
    end
    
    it "处理意见为其他值时，状态变为processing" do
      visit edit_admin_audit_work_order_path(audit_work_order)
      select "需要补充材料", from: "audit_work_order[processing_opinion]"
      click_button "更新审核工单"
      
      visit admin_audit_work_order_path(audit_work_order)
      expect(page).to have_content("processing")
    end
  end
end