require 'rails_helper'

RSpec.describe 'Problem Code Import', type: :system do
  let(:admin_user) { create(:admin_user) }
  let(:csv_path) { Rails.root.join('spec', 'fixtures', 'test_problem_codes.csv') }

  before do
    login_as(admin_user, scope: :admin_user)
    visit '/admin/imports/new?resource=problem_codes'
  end

  it 'imports problem codes and creates fee types correctly' do
    attach_file('file', csv_path)
    select '个人', from: 'meeting_type'
    click_button '导入'

    expect(page).to have_content('导入成功')
    
    # Verify FeeTypes were created
    expect(FeeType.count).to eq(3)
    expect(FeeType.pluck(:title)).to include('月度交通费（销售/SMO/CO）', '电话费', '交通费-市内')

    # Verify ProblemTypes were created and associated
    expect(ProblemType.count).to eq(5)
    expect(ProblemType.pluck(:title)).to include('燃油费行程问题', '出租车行程问题', '手机号未备案', '单次超500问题', '套餐超350元')

    # Verify associations
    transportation = FeeType.find_by(title: '月度交通费（销售/SMO/CO）')
    phone = FeeType.find_by(title: '电话费')
    expect(ProblemType.find_by(title: '燃油费行程问题').fee_type).to eq(transportation)
    expect(ProblemType.find_by(title: '手机号未备案').fee_type).to eq(phone)
  end

  it 'shows import results with correct counts' do
    attach_file('file', csv_path)
    select '个人', from: 'meeting_type'
    click_button '导入'

    expect(page).to have_content('导入结果')
    expect(page).to have_content('导入成功: 3 费用类型, 5 问题类型.')
    expect(page).to have_content('费用类型 (3)')
    expect(page).to have_content('问题类型 (5)')
  end
end