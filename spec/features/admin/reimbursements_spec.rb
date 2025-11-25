require 'rails_helper'

RSpec.describe 'Admin::Reimbursements', type: :feature do
  let!(:admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement) { create(:reimbursement) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe '列表页' do
    before { visit admin_reimbursements_path }

    it '显示报销单列表和相关信息' do
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content(reimbursement.applicant)
      expect(page).to have_content(reimbursement.status) # 检查状态显示
      expect(page).to have_content('否') # 检查 is_electronic 字段显示 (假设默认是 false)
    end

    it '有导入按钮' do
      expect(page).to have_link('导入报销单')
    end
  end

  describe '详情页' do
    before { visit admin_reimbursement_path(reimbursement) }

    it '显示报销单详情和相关信息' do
      expect(page).to have_content(reimbursement.invoice_number)
      expect(page).to have_content(reimbursement.applicant)
      expect(page).to have_content(reimbursement.status) # 检查状态显示
      expect(page).to have_content('否') # 检查 is_electronic 字段显示 (假设默认是 false)
    end

    it '有创建工单按钮' do
      # 假设报销单默认状态是 pending，可以创建工单
      expect(page).to have_link('新建审核工单')
      expect(page).to have_link('新建沟通工单')
    end

    it '根据报销单状态显示状态操作按钮' do
      # 默认 pending 状态，应该有开始处理按钮
      expect(page).to have_link('开始处理')
      expect(page).not_to have_link('处理完成')

      # 更改状态为 processing
      reimbursement.update(status: 'processing')

      # 创建已验证的费用明细，以便显示"处理完成"按钮
      create_list(:fee_detail, 3, document_number: reimbursement.invoice_number, verification_status: 'verified')

      visit admin_reimbursement_path(reimbursement)
      expect(page).not_to have_link('开始处理')
      expect(page).to have_link('处理完成')

      # 更改状态为 close
      reimbursement.update(status: 'close')
      visit admin_reimbursement_path(reimbursement)
      expect(page).not_to have_link('开始处理')
      expect(page).not_to have_link('处理完成')
    end

    it '显示标签页' do
      expect(page).to have_content('基本信息')
      expect(page).to have_content('快递收单工单')
      expect(page).to have_content('审核工单')
      expect(page).to have_content('沟通工单')
      expect(page).to have_content('费用明细')
      expect(page).to have_content('操作历史')
    end
  end

  describe '导入功能' do
    it '显示导入表单' do
      visit new_import_admin_reimbursements_path
      expect(page).to have_content('导入报销单')
      expect(page).to have_button('导入')
    end

    it '处理导入请求并显示结果' do
      visit new_import_admin_reimbursements_path

      # 创建一个临时的 CSV 文件用于上传
      temp_file = Tempfile.new(['test_reimbursements', '.csv'])
      csv_content = <<~CSV
        报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,收单状态,收单日期,提交报销日期,报销单状态,单据标签,报销单审核通过日期,审核通过人
        R202501003,新报销单3,测试用户3,TEST003,测试公司,测试部门,300.00,未收单,,2025-01-03,审批中,,,
      CSV
      temp_file.write(csv_content)
      temp_file.rewind

      # 模拟文件上传
      attach_file('file', temp_file.path)
      click_button '导入'

      # 验证导入结果
      expect(page).to have_content('导入成功: 1 创建, 0 更新.')
      expect(Reimbursement.last.invoice_number).to eq('R202501003')

      temp_file.close
      temp_file.unlink
    end
  end
end
