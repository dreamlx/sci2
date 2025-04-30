require 'rails_helper'

RSpec.describe "审核工单管理", type: :feature do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe "列表页" do
    it "显示所有审核工单" do
      visit admin_audit_work_orders_path
      expect(page).to have_content("审核工单")
      expect(page).to have_content(reimbursement.invoice_number)
    end

    it "可以按状态筛选" do
      visit admin_audit_work_orders_path
      click_link "Pending"
      expect(page).to have_content(reimbursement.invoice_number)
    end
  end

  describe "详情页" do
    it "显示审核工单详细信息" do
      visit admin_audit_work_order_path(audit_work_order)
      expect(page).to have_content("审核工单 ##{audit_work_order.id}")
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content("pending")
    end

    it "显示开始处理按钮" do
      visit admin_audit_work_order_path(audit_work_order)
      expect(page).to have_link("开始处理")
    end
  end

  describe "创建审核工单", js: true do
    it "可以创建新审核工单" do
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)

      # 选择费用明细
      check("audit_work_order[fee_detail_ids][]")

      # 填写表单
      select "发票问题", from: "audit_work_order[problem_type]"
      select "发票信息不完整", from: "audit_work_order[problem_description]"
      fill_in "audit_work_order[remark]", with: "测试备注"
      select "需要补充材料", from: "audit_work_order[processing_opinion]"

      click_button "创建审核工单"

      expect(page).to have_content("审核工单已成功创建")
      expect(page).to have_content("发票问题")
      expect(page).to have_content("测试备注")
    end
  end

  describe "工单状态流转", js: true do
    it "可以开始处理工单" do
      visit admin_audit_work_order_path(audit_work_order)
      accept_alert do
        click_link "开始处理"
      end

      expect(page).to have_content("工单已开始处理")
      expect(page).to have_content("processing")
    end

    it "可以直接审核通过工单" do
      # 工单状态为pending
      visit admin_audit_work_order_path(audit_work_order)
      click_link "审核通过"

      fill_in "audit_work_order[audit_comment]", with: "直接审核通过测试"
      click_button "确认通过"

      expect(page).to have_content("审核已通过")
      expect(page).to have_content("approved")
      expect(page).to have_content("直接审核通过测试")
    end

    it "可以审核通过工单" do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      visit admin_audit_work_order_path(audit_work_order)
      click_link "审核通过"

      fill_in "audit_work_order[audit_comment]", with: "审核通过测试"
      click_button "确认通过"

      expect(page).to have_content("审核已通过")
      expect(page).to have_content("approved")
      expect(page).to have_content("审核通过测试")
    end

    it "可以审核拒绝工单" do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      visit admin_audit_work_order_path(audit_work_order)
      click_link "审核拒绝"

      fill_in "audit_work_order[audit_comment]", with: "审核拒绝测试"
      click_button "确认拒绝"

      expect(page).to have_content("审核已拒绝")
      expect(page).to have_content("rejected")
      expect(page).to have_content("审核拒绝测试")
    end
  end

  describe "费用明细验证", js: true do
    let!(:fee_detail_selection) { create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fee_detail) }

    it "可以更新费用明细验证状态" do
      visit admin_audit_work_order_path(audit_work_order)
      click_link "费用明细"
      click_link "更新验证状态"

      select "已验证", from: "verification_status"
      fill_in "comment", with: "验证通过测试"
      click_button "提交"

      expect(page).to have_content("费用明细 ##{fee_detail.id} 状态已更新")
      visit admin_audit_work_order_path(audit_work_order)
      click_link "费用明细"
      expect(page).to have_content("verified")
      expect(page).to have_content("验证通过测试")
    end
  end
end