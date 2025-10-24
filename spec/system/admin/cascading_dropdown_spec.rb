require 'rails_helper'

RSpec.describe 'Cascading Dropdown and Problem Description Generation', type: :system, js: true do
  let(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'processing') }

  # 创建费用类型
  let!(:fee_type) do
    FeeType.create!(
      code: '00',
      title: '月度交通费',
      meeting_type: '个人',
      active: true
    )
  end

  # 创建问题类型
  let!(:problem_type1) do
    ProblemType.create!(
      code: '01',
      title: '燃油费行程问题',
      sop_description: '根据SOP规定需提供行程',
      standard_handling: '请补充行程信息',
      fee_type: fee_type,
      active: true
    )
  end

  let!(:problem_type2) do
    ProblemType.create!(
      code: '02',
      title: '金额超标',
      sop_description: '检查金额是否超过规定限额',
      standard_handling: '要求说明超标原因',
      fee_type: fee_type,
      active: true
    )
  end

  # 创建费用明细
  let!(:fee_detail) do
    FeeDetail.create!(
      document_number: 'R202501001',
      fee_type: '交通费',
      amount: 100.00,
      verification_status: 'pending'
    )
  end

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe '审核工单拒绝表单' do
    it '测试级联下拉列表和问题描述自动生成' do
      # 访问报销单详情页
      visit admin_reimbursement_path(reimbursement)

      # 创建审核工单
      click_link '新建审核工单'

      # 选择费用明细
      check "audit_work_order_submitted_fee_detail_ids_#{fee_detail.id}"

      # 提交表单创建工单
      click_button '创建审核工单'

      # 验证工单创建成功
      expect(page).to have_content('审核工单已成功创建')

      # 点击拒绝按钮
      click_link '审核拒绝'

      # 选择费用类型
      select "#{fee_type.code} - #{fee_type.title}", from: 'fee_type_select'

      # 等待问题类型下拉列表加载
      sleep(1)

      # 选择问题类型
      select "#{problem_type1.code} - #{problem_type1.title}", from: 'problem_type_select'

      # 验证审核意见字段是否自动填充了标准处理方法
      expect(page).to have_field('audit_work_order_audit_comment', with: problem_type1.standard_handling)

      # 提交拒绝表单
      click_button '确认拒绝'

      # 验证工单拒绝成功
      expect(page).to have_content('审核已拒绝')

      # 验证工单状态已更新
      expect(page).to have_css('.status_tag', text: 'rejected')
    end
  end

  describe '审核工单表单' do
    it '测试当只有一个问题类型时自动选择' do
      # 删除第二个问题类型，只保留一个
      problem_type2.destroy

      # 访问报销单详情页
      visit admin_reimbursement_path(reimbursement)

      # 创建审核工单
      click_link '新建审核工单'

      # 选择费用明细
      check "audit_work_order_submitted_fee_detail_ids_#{fee_detail.id}"

      # 提交表单创建工单
      click_button '创建审核工单'

      # 验证工单创建成功
      expect(page).to have_content('审核工单已成功创建')

      # 点击拒绝按钮
      click_link '审核拒绝'

      # 选择费用类型
      select "#{fee_type.code} - #{fee_type.title}", from: 'fee_type_select'

      # 等待问题类型下拉列表加载和自动选择
      sleep(1)

      # 验证问题类型是否自动选择
      expect(page).to have_select('problem_type_select', selected: "#{problem_type1.code} - #{problem_type1.title}")

      # 验证审核意见字段是否自动填充了标准处理方法
      expect(page).to have_field('audit_work_order_audit_comment', with: problem_type1.standard_handling)
    end
  end

  describe '多个问题添加' do
    it '测试添加多个问题到审核描述' do
      # 访问报销单详情页
      visit admin_reimbursement_path(reimbursement)

      # 创建审核工单
      click_link '新建审核工单'

      # 选择费用明细
      check "audit_work_order_submitted_fee_detail_ids_#{fee_detail.id}"

      # 提交表单创建工单
      click_button '创建审核工单'

      # 验证工单创建成功
      expect(page).to have_content('审核工单已成功创建')

      # 点击拒绝按钮
      click_link '审核拒绝'

      # 选择费用类型
      select "#{fee_type.code} - #{fee_type.title}", from: 'fee_type_select'

      # 等待问题类型下拉列表加载
      sleep(1)

      # 选择第一个问题类型
      select "#{problem_type1.code} - #{problem_type1.title}", from: 'problem_type_select'

      # 验证审核意见字段是否自动填充了标准处理方法
      expect(page).to have_field('audit_work_order_audit_comment', with: problem_type1.standard_handling)

      # 修改审核意见，添加第一个问题的描述
      first_problem_text = "#{fee_type.code} - #{fee_type.title}: #{problem_type1.code} - #{problem_type1.title}\n#{problem_type1.sop_description}\n#{problem_type1.standard_handling}"
      fill_in 'audit_work_order_audit_comment', with: first_problem_text

      # 选择第二个问题类型
      select "#{problem_type2.code} - #{problem_type2.title}", from: 'problem_type_select'

      # 验证审核意见字段是否更新为第二个问题的标准处理方法
      expect(page).to have_field('audit_work_order_audit_comment', with: problem_type2.standard_handling)

      # 修改审核意见，添加两个问题的描述
      combined_text = "#{first_problem_text}\n\n#{fee_type.code} - #{fee_type.title}: #{problem_type2.code} - #{problem_type2.title}\n#{problem_type2.sop_description}\n#{problem_type2.standard_handling}"
      fill_in 'audit_work_order_audit_comment', with: combined_text

      # 提交拒绝表单
      click_button '确认拒绝'

      # 验证工单拒绝成功
      expect(page).to have_content('审核已拒绝')

      # 验证工单状态已更新
      expect(page).to have_css('.status_tag', text: 'rejected')

      # 验证审核意见包含两个问题的描述
      expect(page).to have_content(problem_type1.standard_handling)
      expect(page).to have_content(problem_type2.standard_handling)
    end
  end
end
