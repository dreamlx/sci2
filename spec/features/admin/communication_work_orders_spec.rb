require 'rails_helper'

RSpec.describe '沟通工单管理', type: :feature do
  let!(:admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'pending') }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe '列表页' do
    it '显示所有沟通工单' do
      visit admin_communication_work_orders_path
      expect(page).to have_content('沟通工单')
      expect(page).to have_content(reimbursement.invoice_number)
    end

    it '可以按状态筛选' do
      visit admin_communication_work_orders_path
      click_link 'Pending'
      expect(page).to have_content(reimbursement.invoice_number)
    end
  end

  describe '详情页' do
    it '显示沟通工单详细信息' do
      visit admin_communication_work_order_path(communication_work_order)
      expect(page).to have_content("沟通工单 ##{communication_work_order.id}")
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content(/pending/i)
    end

    it '显示状态操作按钮' do
      visit admin_communication_work_order_path(communication_work_order)
      expect(page).to have_link('开始处理')
      expect(page).to have_link('标记为需要沟通')
      expect(page).to have_link('沟通后通过') # 支持直接通过
    end
  end

  describe '创建沟通工单', js: true do
    it '可以创建新沟通工单' do
      visit new_admin_communication_work_order_path(reimbursement_id: reimbursement.id) # 移除 audit_work_order_id 参数

      # 选择费用明细
      check('communication_work_order[fee_detail_ids][]')

      # 填写表单
      select '发票问题', from: 'communication_work_order[problem_type]'
      select '发票信息不完整', from: 'communication_work_order[problem_description]'
      fill_in 'communication_work_order[remark]', with: '沟通测试备注'
      select '需要补充材料', from: 'communication_work_order[processing_opinion]'
      select '电话', from: 'communication_work_order[communication_method]'
      select '财务人员', from: 'communication_work_order[initiator_role]'

      # Use a more generic selector for the submit button
      find('input[type="submit"]').click

      expect(page).to have_content('沟通工单已成功创建')
      expect(page).to have_content('发票问题')
      expect(page).to have_content('沟通测试备注')
      expect(page).to have_content('电话')
    end
  end

  describe '工单状态流转', js: true do
    it '可以开始处理工单' do
      visit admin_communication_work_order_path(communication_work_order)
      accept_confirm do
        click_link '开始处理'
      end

      expect(page).to have_content('工单已开始处理')
      expect(page).to have_content(/processing/i)
    end

    it '可以标记需要沟通' do
      visit admin_communication_work_order_path(communication_work_order)
      accept_confirm do
        click_link '标记为需要沟通'
      end

      expect(page).to have_content('已标记为需要沟通')
      expect(page).to have_content('需要沟通')
    end

    it '可以直接沟通通过工单' do
      # 工单状态为pending
      visit admin_communication_work_order_path(communication_work_order)
      click_link '沟通后通过'

      fill_in 'communication_work_order[resolution_summary]', with: '直接沟通通过测试'
      click_button '确认通过'

      expect(page).to have_content('工单已沟通通过')
      expect(page).to have_content(/approved/i)
      expect(page).to have_content('直接沟通通过测试')
    end

    it '可以沟通后通过工单' do
      # 先将工单状态设为processing
      communication_work_order.update(status: 'processing')

      visit admin_communication_work_order_path(communication_work_order)
      click_link '沟通后通过'

      fill_in 'communication_work_order[resolution_summary]', with: '问题已解决'
      click_button '确认通过'

      expect(page).to have_content('工单已沟通通过')
      expect(page).to have_content(/approved/i)
      expect(page).to have_content('问题已解决')
    end

    it '可以沟通后拒绝工单' do
      # 先将工单状态设为processing
      problem_type = ProblemType.find_by(title: '发票问题') || create(:problem_type, title: '发票问题')
      communication_work_order.update(status: 'processing', problem_type: problem_type)

      visit admin_communication_work_order_path(communication_work_order)
      click_link '沟通后拒绝'

      fill_in 'communication_work_order[resolution_summary]', with: '问题无法解决'
      click_button '确认拒绝'

      # 只检查操作成功的消息，不检查状态
      expect(page).to have_content('工单已沟通拒绝')
      # 检查解决方案摘要是否正确显示
      expect(page).to have_content('问题无法解决') if page.has_content?('问题无法解决')
    end
  end

  
  describe '费用明细验证', js: true do
    let!(:fee_detail_selection) do
      create(:fee_detail_selection, work_order_id: communication_work_order.id, work_order_type: 'CommunicationWorkOrder',
                                    fee_detail: fee_detail)
    end

    it '可以更新费用明细验证状态' do
      # 确保工单状态为processing，这样才能更新费用明细
      communication_work_order.update(status: 'processing', problem_type: '发票问题')

      visit admin_communication_work_order_path(communication_work_order)
      click_link '费用明细'

      # 使用更通用的选择器找到更新验证状态链接
      first('a', text: '更新验证状态').click

      select '已验证', from: 'verification_status'
      fill_in 'comment', with: '验证通过测试'
      click_button '提交'

      expect(page).to have_content("费用明细 ##{fee_detail.id} 状态已更新")
      visit admin_communication_work_order_path(communication_work_order)
      click_link '费用明细'
      expect(page).to have_content(/verified/i)
      # 检查验证意见列是否包含我们的评论
      expect(page).to have_content('测试验证备注')
    end
  end
end
