require 'rails_helper'

RSpec.describe "审核工单页面逻辑", type: :feature, js: true do
  let(:admin_user) { create(:admin_user) }
  
  let(:reimbursement) do
    create(:reimbursement, 
      invoice_number: "INV-001",
      document_name: "个人报销单",
      status: "processing",
      is_electronic: true
    )
  end
  
  let!(:fee_detail1) do
    create(:fee_detail, 
      document_number: reimbursement.invoice_number,
      fee_type: "会议讲课费",
      amount: 100.0,
      verification_status: "pending"
    )
  end
  
  let!(:fee_detail2) do
    create(:fee_detail, 
      document_number: reimbursement.invoice_number,
      fee_type: "差旅费",
      amount: 200.0,
      verification_status: "pending"
    )
  end
  
  let!(:fee_type1) do
    create(:fee_type, 
      code: "FT001",
      title: "会议讲课费",
      meeting_type: "个人",
      active: true
    )
  end
  
  let!(:fee_type2) do
    create(:fee_type, 
      code: "FT002",
      title: "差旅费",
      meeting_type: "个人",
      active: true
    )
  end
  
  let!(:problem_type1) do
    create(:problem_type, 
      code: "PT001",
      title: "发票不合规",
      sop_description: "发票信息不完整",
      standard_handling: "请提供完整发票",
      fee_type: fee_type1,
      active: true
    )
  end
  
  let!(:problem_type2) do
    create(:problem_type, 
      code: "PT002",
      title: "金额不匹配",
      sop_description: "发票金额与申报金额不一致",
      standard_handling: "请核对金额",
      fee_type: fee_type1,
      active: true
    )
  end
  
  let!(:problem_type3) do
    create(:problem_type, 
      code: "PT003",
      title: "行程不合理",
      sop_description: "行程安排不合理",
      standard_handling: "请提供详细行程说明",
      fee_type: fee_type2,
      active: true
    )
  end
  
  before do
    login_as(admin_user)
    visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
  end
  
  describe "费用明细选择" do
    it "选择费用明细后显示费用类型标签" do
      # 选择费用明细
      check "fee_detail_#{fee_detail1.id}"
      
      # 验证费用类型标签显示
      within '.fee-type-tags-container' do
        expect(page).to have_content('会议讲课费')
      end
    end
    
    it "选择多个费用明细时按费用类型分组显示" do
      # 选择多个费用明细
      check "fee_detail_#{fee_detail1.id}"
      check "fee_detail_#{fee_detail2.id}"
      
      # 验证费用类型标签显示
      within '.fee-type-tags-container' do
        expect(page).to have_content('会议讲课费')
        expect(page).to have_content('差旅费')
      end
    end
  end
  
  describe "处理意见与问题类型显示逻辑" do
    context "处理意见为'可以通过'" do
      it "显示费用类型标签但不显示问题类型选择区域" do
        # 选择费用明细
        check "fee_detail_#{fee_detail1.id}"
        
        # 选择处理意见
        select '可以通过', from: 'audit_work_order_processing_opinion'
        
        # 验证费用类型标签显示
        within '.fee-type-tags-container' do
          expect(page).to have_content('会议讲课费')
        end
        
        # 验证问题类型选择区域不显示
        expect(page).not_to have_css('.problem-type-checkboxes:visible')
      end
    end
    
    context "处理意见为'无法通过'" do
      it "显示费用类型标签和相关问题类型选择区域" do
        # 选择费用明细
        check "fee_detail_#{fee_detail1.id}"
        
        # 选择处理意见
        select '无法通过', from: 'audit_work_order_processing_opinion'
        
        # 验证费用类型标签显示
        within '.fee-type-tags-container' do
          expect(page).to have_content('会议讲课费')
        end
        
        # 验证问题类型选择区域显示
        expect(page).to have_css('.problem-type-checkboxes:visible')
        
        # 验证只显示与已选费用类型相关的问题类型
        within '.problem-type-checkboxes' do
          expect(page).to have_content('发票不合规')
          expect(page).to have_content('金额不匹配')
          expect(page).not_to have_content('行程不合理')
        end
      end
      
      it "选择多个费用类型时显示所有相关问题类型" do
        # 选择多个费用明细
        check "fee_detail_#{fee_detail1.id}"
        check "fee_detail_#{fee_detail2.id}"
        
        # 选择处理意见
        select '无法通过', from: 'audit_work_order_processing_opinion'
        
        # 验证显示所有相关问题类型
        within '.problem-type-checkboxes' do
          expect(page).to have_content('发票不合规')
          expect(page).to have_content('金额不匹配')
          expect(page).to have_content('行程不合理')
        end
      end
    end
    
    context "其他处理意见" do
      it "不显示费用类型标签和问题类型选择区域" do
        # 选择费用明细
        check "fee_detail_#{fee_detail1.id}"
        
        # 选择其他处理意见
        select '需要沟通', from: 'audit_work_order_processing_opinion'
        
        # 验证费用类型标签不显示
        expect(page).not_to have_css('.fee-type-tags-container:visible')
        
        # 验证问题类型选择区域不显示
        expect(page).not_to have_css('.problem-type-checkboxes:visible')
      end
    end
  end
  
  describe "表单验证逻辑" do
    context "处理意见为'可以通过'" do
      it "必须选择至少一个费用明细" do
        # 不选择费用明细
        
        # 选择处理意见
        select '可以通过', from: 'audit_work_order_processing_opinion'
        
        # 填写审核意见
        fill_in 'audit_work_order_audit_comment', with: '审核通过'
        
        # 提交表单
        click_button '创建审核工单'
        
        # 验证错误提示
        expect(page).to have_content('必须选择至少一个费用明细')
      end
      
      it "不需要选择问题类型" do
        # 选择费用明细
        check "fee_detail_#{fee_detail1.id}"
        
        # 选择处理意见
        select '可以通过', from: 'audit_work_order_processing_opinion'
        
        # 填写审核意见
        fill_in 'audit_work_order_audit_comment', with: '审核通过'
        
        # 提交表单
        click_button '创建审核工单'
        
        # 验证成功创建
        expect(page).to have_content('审核工单创建成功')
      end
    end
    
    context "处理意见为'无法通过'" do
      it "必须选择至少一个费用明细" do
        # 不选择费用明细
        
        # 选择处理意见
        select '无法通过', from: 'audit_work_order_processing_opinion'
        
        # 填写审核意见
        fill_in 'audit_work_order_audit_comment', with: '审核不通过'
        
        # 提交表单
        click_button '创建审核工单'
        
        # 验证错误提示
        expect(page).to have_content('必须选择至少一个费用明细')
      end
      
      it "必须选择至少一个问题类型" do
        # 选择费用明细
        check "fee_detail_#{fee_detail1.id}"
        
        # 选择处理意见
        select '无法通过', from: 'audit_work_order_processing_opinion'
        
        # 填写审核意见但不选择问题类型
        fill_in 'audit_work_order_audit_comment', with: '审核不通过'
        
        # 提交表单
        click_button '创建审核工单'
        
        # 验证错误提示
        expect(page).to have_content('当处理意见为\'不通过\'时，必须选择至少一个问题类型')
      end
      
      it "选择问题类型后可以成功创建" do
        # 选择费用明细
        check "fee_detail_#{fee_detail1.id}"
        
        # 选择处理意见
        select '无法通过', from: 'audit_work_order_processing_opinion'
        
        # 填写审核意见
        fill_in 'audit_work_order_audit_comment', with: '审核不通过'
        
        # 选择问题类型
        within '.problem-type-checkboxes' do
          check "problem_type_#{problem_type1.id}"
        end
        
        # 提交表单
        click_button '创建审核工单'
        
        # 验证成功创建
        expect(page).to have_content('审核工单创建成功')
      end
    end
  end
  
  describe "费用明细状态变化" do
    it "创建通过的审核工单后费用明细状态变为verified" do
      # 选择费用明细
      check "fee_detail_#{fee_detail1.id}"
      
      # 选择处理意见
      select '可以通过', from: 'audit_work_order_processing_opinion'
      
      # 填写审核意见
      fill_in 'audit_work_order_audit_comment', with: '审核通过'
      
      # 提交表单
      click_button '创建审核工单'
      
      # 验证成功创建
      expect(page).to have_content('审核工单创建成功')
      
      # 验证费用明细状态
      expect(fee_detail1.reload.verification_status).to eq('verified')
    end
    
    it "创建拒绝的审核工单后费用明细状态变为problematic" do
      # 选择费用明细
      check "fee_detail_#{fee_detail1.id}"
      
      # 选择处理意见
      select '无法通过', from: 'audit_work_order_processing_opinion'
      
      # 填写审核意见
      fill_in 'audit_work_order_audit_comment', with: '审核不通过'
      
      # 选择问题类型
      within '.problem-type-checkboxes' do
        check "problem_type_#{problem_type1.id}"
      end
      
      # 提交表单
      click_button '创建审核工单'
      
      # 验证成功创建
      expect(page).to have_content('审核工单创建成功')
      
      # 验证费用明细状态
      expect(fee_detail1.reload.verification_status).to eq('problematic')
    end
    
    it "最新工单决定费用明细状态" do
      # 先创建拒绝的工单
      check "fee_detail_#{fee_detail1.id}"
      select '无法通过', from: 'audit_work_order_processing_opinion'
      fill_in 'audit_work_order_audit_comment', with: '审核不通过'
      within '.problem-type-checkboxes' do
        check "problem_type_#{problem_type1.id}"
      end
      click_button '创建审核工单'
      
      # 验证费用明细状态
      expect(fee_detail1.reload.verification_status).to eq('problematic')
      
      # 再创建通过的工单
      visit new_admin_audit_work_order_path(reimbursement_id: reimbursement.id)
      check "fee_detail_#{fee_detail1.id}"
      select '可以通过', from: 'audit_work_order_processing_opinion'
      fill_in 'audit_work_order_audit_comment', with: '审核通过'
      click_button '创建审核工单'
      
      # 验证费用明细状态变为verified
      expect(fee_detail1.reload.verification_status).to eq('verified')
    end
  end
end