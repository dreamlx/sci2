# spec/support/system_test_helpers.rb
module SystemTestHelpers
  # Helper method to attach a file in a system test
  def attach_file_in_import_form(file_path)
    attach_file('file', file_path)
    click_button '导入'
  end
  
  # Helper method to login as admin user
  def login_as_admin
    admin = create(:admin_user)
    login_as(admin, scope: :admin_user)
    admin
  end
  
  # Helper method to create test reimbursements
  def create_test_reimbursements
    create(:reimbursement, invoice_number: 'R202501001')
    create(:reimbursement, invoice_number: 'R202501002', is_electronic: true)
  end
  
  # Helper method to verify import success message
  def expect_import_success
    expect(page).to have_content('导入成功')
  end
  
  # Helper method to verify import error message
  def expect_import_error
    expect(page).to have_content('导入失败')
  end
  
  # Helper method to verify unmatched items message
  def expect_unmatched_items
    expect(page).to have_content('未匹配')
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end