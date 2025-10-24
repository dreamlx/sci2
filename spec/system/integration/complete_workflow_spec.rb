require 'rails_helper'

RSpec.describe '完整工单处理流程', type: :system, js: true do
  let(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }

  # 创建费用明细
  let!(:fee_detail1) do
    create(:fee_detail, document_number: 'R202501001', fee_type: '交通费', amount: 100.00, verification_status: 'pending')
  end
  let!(:fee_detail2) do
    create(:fee_detail, document_number: 'R202501001', fee_type: '住宿费', amount: 200.00, verification_status: 'pending')
  end
  let!(:fee_detail3) do
    create(:fee_detail, document_number: 'R202501001', fee_type: '餐饮费', amount: 150.00, verification_status: 'pending')
  end

  # 创建费用类型
  let!(:fee_type1) do
    FeeType.create!(
      code: '00',
      title: '月度交通费',
      meeting_type: '个人',
      active: true
    )
  end

  let!(:fee_type2) do
    FeeType.create!(
      code: '01',
      title: '住宿费',
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
      fee_type: fee_type1,
      active: true
    )
  end

  let!(:problem_type2) do
    ProblemType.create!(
      code: '02',
      title: '金额超标',
      sop_description: '检查金额是否超过规定限额',
      standard_handling: '要求说明超标原因',
      fee_type: fee_type1,
      active: true
    )
  end

  let!(:problem_type3) do
    ProblemType.create!(
      code: '01',
      title: '住宿天数与行程不符',
      sop_description: '核对住宿天数与行程安排',
      standard_handling: '要求提供行程说明',
      fee_type: fee_type2,
      active: true
    )
  end

  before do
    login_as(admin_user, scope: :admin_user)
  end

  it '完整测试工单处理流程' do
    # 第一部分：创建沟通工单并添加问题

    # 访问报销单详情页
    visit admin_reimbursement_path(reimbursement)
    expect(page).to have_content(reimbursement.invoice_number)

    # 创建沟通工单
    click_link '新建沟通工单'
    expect(page).to have_content('新建沟通工单')

    # 选择费用明细
    check "communication_work_order_submitted_fee_detail_ids_#{fee_detail1.id}"
    check "communication_work_order_submitted_fee_detail_ids_#{fee_detail2.id}"

    # 提交表单创建工单
    click_button '创建沟通工单'
    expect(page).to have_content('沟通工单已成功创建')

    # 验证工单创建成功
    expect(page).to have_css('.status_tag', text: 'pending')

    # 点击拒绝按钮
    click_link '审核拒绝'
    expect(page).to have_content('审核拒绝')

    # 选择第一个费用类型和问题类型
    select "#{fee_type1.code} - #{fee_type1.title}", from: 'fee_type_select'
    sleep(1) # 等待问题类型加载

    select "#{problem_type1.code} - #{problem_type1.title}", from: 'problem_type_select'
    sleep(1) # 等待问题描述自动填充

    # 验证审核意见字段是否自动填充了标准处理方法
    expect(page).to have_field('communication_work_order_audit_comment', with: problem_type1.standard_handling)

    # 修改审核意见，添加第一个问题描述
    first_problem_text = "#{fee_type1.code} - #{fee_type1.title}: #{problem_type1.code} - #{problem_type1.title}\n#{problem_type1.sop_description}\n#{problem_type1.standard_handling}"
    fill_in 'communication_work_order_audit_comment', with: first_problem_text

    # 选择第二个费用类型和问题类型
    select "#{fee_type2.code} - #{fee_type2.title}", from: 'fee_type_select'
    sleep(1) # 等待问题类型加载

    select "#{problem_type3.code} - #{problem_type3.title}", from: 'problem_type_select'
    sleep(1) # 等待问题描述自动填充

    # 修改审核意见，添加两个问题的描述
    combined_text = "#{first_problem_text}\n\n#{fee_type2.code} - #{fee_type2.title}: #{problem_type3.code} - #{problem_type3.title}\n#{problem_type3.sop_description}\n#{problem_type3.standard_handling}"
    fill_in 'communication_work_order_audit_comment', with: combined_text

    # 提交拒绝表单
    click_button '确认拒绝'

    # 验证工单拒绝成功
    expect(page).to have_content('审核已拒绝')
    expect(page).to have_css('.status_tag', text: 'rejected')

    # 验证审核意见包含两个问题的描述
    expect(page).to have_content(problem_type1.standard_handling)
    expect(page).to have_content(problem_type3.standard_handling)

    # 验证费用明细状态更新
    visit admin_fee_detail_path(fee_detail1)
    expect(page).to have_content('problematic')

    visit admin_fee_detail_path(fee_detail2)
    expect(page).to have_content('problematic')

    # 第二部分：创建审核工单并拒绝

    # 访问报销单详情页
    visit admin_reimbursement_path(reimbursement)

    # 创建审核工单
    click_link '新建审核工单'
    expect(page).to have_content('新建审核工单')

    # 选择费用明细
    check "audit_work_order_submitted_fee_detail_ids_#{fee_detail1.id}"
    check "audit_work_order_submitted_fee_detail_ids_#{fee_detail3.id}"

    # 提交表单创建工单
    click_button '创建审核工单'
    expect(page).to have_content('审核工单已成功创建')

    # 验证工单创建成功
    expect(page).to have_css('.status_tag', text: 'pending')

    # 点击拒绝按钮
    click_link '审核拒绝'
    expect(page).to have_content('审核拒绝')

    # 选择费用类型和问题类型
    select "#{fee_type1.code} - #{fee_type1.title}", from: 'fee_type_select'
    sleep(1) # 等待问题类型加载

    select "#{problem_type2.code} - #{problem_type2.title}", from: 'problem_type_select'
    sleep(1) # 等待问题描述自动填充

    # 验证审核意见字段是否自动填充了标准处理方法
    expect(page).to have_field('audit_work_order_audit_comment', with: problem_type2.standard_handling)

    # 提交拒绝表单
    click_button '确认拒绝'

    # 验证工单拒绝成功
    expect(page).to have_content('审核已拒绝')
    expect(page).to have_css('.status_tag', text: 'rejected')

    # 验证费用明细状态更新
    visit admin_fee_detail_path(fee_detail1)
    expect(page).to have_content('problematic')

    visit admin_fee_detail_path(fee_detail3)
    expect(page).to have_content('problematic')

    # 第三部分：创建审核工单并通过

    # 访问报销单详情页
    visit admin_reimbursement_path(reimbursement)

    # 创建审核工单
    click_link '新建审核工单'
    expect(page).to have_content('新建审核工单')

    # 选择费用明细
    check "audit_work_order_submitted_fee_detail_ids_#{fee_detail1.id}"

    # 提交表单创建工单
    click_button '创建审核工单'
    expect(page).to have_content('审核工单已成功创建')

    # 验证工单创建成功
    expect(page).to have_css('.status_tag', text: 'pending')

    # 点击通过按钮
    click_link '审核通过'
    expect(page).to have_content('审核通过')

    # 填写审核意见
    fill_in 'audit_work_order_audit_comment', with: '审核通过，问题已解决'

    # 提交通过表单
    click_button '确认通过'

    # 验证工单通过成功
    expect(page).to have_content('审核已通过')
    expect(page).to have_css('.status_tag', text: 'approved')

    # 验证费用明细状态更新（根据"最新工单决定"原则）
    visit admin_fee_detail_path(fee_detail1)
    expect(page).to have_content('verified')

    # 验证报销单状态
    visit admin_reimbursement_path(reimbursement)
    expect(page).to have_content('processing')

    # 验证其他费用明细状态保持不变
    visit admin_fee_detail_path(fee_detail2)
    expect(page).to have_content('problematic')

    visit admin_fee_detail_path(fee_detail3)
    expect(page).to have_content('problematic')
  end
end
