require 'rails_helper'

RSpec.describe "沟通工单管理", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'pending') } # 移除 audit_work_order 关联

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "列表页" do
    it "显示所有沟通工单" do
      visit admin_communication_work_orders_path
      expect(page).to have_content("沟通工单")
      expect(page).to have_content(reimbursement.invoice_number)
    end

    it "可以按状态筛选" do
      visit admin_communication_work_orders_path
      click_link "Pending"
      expect(page).to have_content(reimbursement.invoice_number)
    end
  end

  describe "详情页" do
    it "显示沟通工单详细信息" do
      visit admin_communication_work_order_path(communication_work_order)
      expect(page).to have_content("沟通工单 ##{communication_work_order.id}")
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content("pending")
    end

    it "显示状态操作按钮" do
      visit admin_communication_work_order_path(communication_work_order)
      expect(page).to have_link("开始处理")
      expect(page).to have_link("标记需沟通")
    end
  end

  describe "创建沟通工单", js: true do
    it "可以创建新沟通工单" do
      visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id) # 移除 audit_work_order_id 参数

      # 选择费用明细
      check("communication_work_order[fee_detail_ids][]")

      # 填写表单
      select "发票问题", from: "communication_work_order[problem_type]"
      select "发票信息不完整", from: "communication_work_order[problem_description]"
      fill_in "communication_work_order[remark]", with: "沟通测试备注"
      select "需要补充材料", from: "communication_work_order[processing_opinion]"
      select "电话", from: "communication_work_order[communication_method]"
      select "财务人员", from: "communication_work_order[initiator_role]"

      click_button "创建沟通工单"

      expect(page).to have_content("沟通工单已成功创建")
      expect(page).to have_content("发票问题")
      expect(page).to have_content("沟通测试备注")
      expect(page).to have_content("电话")
    end
  end

  describe "工单状态流转", js: true do
    it "可以开始处理工单" do
      visit admin_communication_work_order_path(communication_work_order)
      click_link "开始处理"

      expect(page).to have_content("工单已开始处理")
      expect(page).to have_content("processing")
    end

    it "可以标记需要沟通" do
      visit admin_communication_work_order_path(communication_work_order)
      click_link "标记需沟通"

      expect(page).to have_content("工单已标记为需要沟通")
      expect(page).to have_content("needs_communication")
    end

    it "可以沟通后通过工单" do
      # 先将工单状态设为needs_communication
      communication_work_order.update(status: 'needs_communication')

      visit admin_communication_work_order_path(communication_work_order)
      click_link "沟通后通过"

      fill_in "communication_work_order[resolution_summary]", with: "问题已解决"
      click_button "确认通过"

      expect(page).to have_content("工单已沟通通过")
      expect(page).to have_content("approved")
      expect(page).to have_content("问题已解决")
    end

    it "可以沟通后拒绝工单" do
      # 先将工单状态设为needs_communication
      communication_work_order.update(status: 'needs_communication')

      visit admin_communication_work_order_path(communication_work_order)
      click_link "沟通后拒绝"

      fill_in "communication_work_order[resolution_summary]", with: "问题无法解决"
      click_button "确认拒绝"

      expect(page).to have_content("工单已沟通拒绝")
      expect(page).to have_content("rejected")
      expect(page).to have_content("问题无法解决")
    end
  end

  describe "沟通记录管理", js: true do
    it "可以添加沟通记录" do
      visit admin_communication_work_order_path(communication_work_order)
      click_link "添加沟通记录"

      fill_in "communication_record[content]", with: "已与申请人沟通，问题已解决"
      select "财务人员", from: "communication_record[communicator_role]"
      fill_in "communication_record[communicator_name]", with: "张三"
      select "电话", from: "communication_record[communication_method]"

      click_button "添加记录"

      expect(page).to have_content("沟通记录已添加")

      click_link "沟通记录"
      expect(page).to have_content("已与申请人沟通，问题已解决")
      expect(page).to have_content("张三")
      expect(page).to have_content("电话")
    end
  end

  describe "费用明细验证", js: true do
    let!(:fee_detail_selection) { create(:fee_detail_selection, work_order: communication_work_order, fee_detail: fee_detail) }

    it "可以更新费用明细验证状态" do
      visit admin_communication_work_order_path(communication_work_order)
      click_link "费用明细"
      click_link "更新验证状态"

      select "已验证", from: "verification_status"
      fill_in "comment", with: "验证通过测试"
      click_button "提交"

      expect(page).to have_content("费用明细 ##{fee_detail.id} 状态已更新")
      visit admin_communication_work_order_path(communication_work_order)
      click_link "费用明细"
      expect(page).to have_content("verified")
      expect(page).to have_content("验证通过测试")
    end
  end
end