# spec/features/admin/reimbursement_completion_spec.rb

require 'rails_helper'

RSpec.describe "Reimbursement Completion", type: :feature do
  let(:admin_user) { create(:admin_user) }
  
  before do
    login_as(admin_user, scope: :admin_user)
  end
  
  describe "WF-CL-002: 处理完成按钮功能" do
    let!(:reimbursement) { create(:reimbursement, status: 'processing') }
    
    context "when all fee details are verified" do
      before do
        create_list(:fee_detail, 3, document_number: reimbursement.invoice_number, verification_status: 'verified')
        visit admin_reimbursement_path(reimbursement)
      end
      
      it "shows the 'Complete Processing' button" do
        expect(page).to have_link("处理完成")
      end
      
      it "changes reimbursement status to close when clicked" do
        click_link "处理完成"
        
        # 确认对话框
        page.driver.browser.switch_to.alert.accept
        
        expect(page).to have_content("报销单已标记为处理完成")
        expect(reimbursement.reload.status).to eq('close')
      end
    end
    
    context "when some fee details are not verified" do
      before do
        create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'verified')
        create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'problematic')
        visit admin_reimbursement_path(reimbursement)
      end
      
      it "does not show the 'Complete Processing' button" do
        expect(page).not_to have_link("处理完成")
      end
    end
  end
end