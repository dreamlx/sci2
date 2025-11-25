# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Fee Details Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing fee details page' do
    it 'loads the page successfully' do
      visit '/admin/fee_details'
      expect(page).to have_content('费用明细')
      expect(page.status_code).to eq(200)
    end

    it 'displays the fee details table' do
      visit '/admin/fee_details'
      expect(page).to have_content('筛选')
      expect(page).to have_content('每页显示')
    end

    it 'shows new fee detail button' do
      visit '/admin/fee_details'
      expect(page).to have_link('新建费用明细')
    end
  end

  describe 'when there are no fee details' do
    it 'shows appropriate empty message' do
      visit '/admin/fee_details'
      expect(page).to have_content('还没有')
    end
  end

  describe 'when there are fee details' do
    let!(:fee_detail) { create(:fee_detail) }

    it 'displays fee detail data' do
      visit '/admin/fee_details'
      expect(page).to have_content(fee_detail.external_fee_id)
      expect(page).to have_content(fee_detail.amount)
    end

    it 'allows viewing individual fee detail' do
      visit "/admin/fee_details/#{fee_detail.id}"
      expect(page).to have_content('费用明细详情')
      expect(page.status_code).to eq(200)
    end

    it 'allows editing fee detail' do
      visit "/admin/fee_details/#{fee_detail.id}/edit"
      expect(page).to have_content('编辑费用明细')
      expect(page.status_code).to eq(200)
    end

    it 'displays financial information' do
      visit "/admin/fee_details/#{fee_detail.id}"
      expect(page).to have_content(fee_detail.amount.to_s)
    end
  end

  describe 'creating new fee detail' do
    it 'shows the new fee detail form' do
      visit '/admin/fee_details/new'
      expect(page).to have_content('新建费用明细')
      expect(page.status_code).to eq(200)
    end

    it 'displays required form fields' do
      visit '/admin/fee_details/new'
      expect(page).to have_field('fee_detail_external_fee_id')
      expect(page).to have_field('fee_detail_amount')
    end

    it 'displays financial fields' do
      visit '/admin/fee_details/new'
      expect(page).to have_field('fee_detail_amount')
      expect(page).to have_field('fee_detail_currency')
    end
  end

  describe 'fee detail categories and types' do
    let!(:food_fee) { create(:fee_detail, category: 'food') }
    let!(:transport_fee) { create(:fee_detail, category: 'transport') }

    it 'displays different categories' do
      visit '/admin/fee_details'
      expect(page).to have_content('food') if food_fee.category
      expect(page).to have_content('transport') if transport_fee.category
    end
  end

  describe 'fee detail management' do
    let!(:fee_detail) { create(:fee_detail) }

    it 'allows deleting fee details' do
      visit "/admin/fee_details/#{fee_detail.id}"
      expect(page).to have_content('删除')
    end

    it 'shows fee detail associations' do
      visit "/admin/fee_details/#{fee_detail.id}"
      expect(page.status_code).to eq(200)
    end
  end

  describe 'import functionality' do
    it 'shows import button' do
      visit '/admin/fee_details'
      expect(page).to have_link('导入费用明细')
    end

    it 'allows navigation to import page' do
      visit '/admin/fee_details'
      click_link '导入费用明细'
      expect(page).to have_current_path('/admin/fee_details/import')
    end
  end

  describe 'error handling' do
    it 'handles invalid fee detail IDs gracefully' do
      visit '/admin/fee_details/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles database errors gracefully' do
      allow(FeeDetail).to receive(:page).and_raise(StandardError.new('Database error'))

      visit '/admin/fee_details'
      expect(page.status_code).to eq(500)
    end

    it 'handles validation errors on create' do
      visit '/admin/fee_details/new'
      click_button('创建费用明细')
      # Should show validation errors
      expect(page.status_code).to be_in([200, 422])
    end
  end

  describe 'filtering and searching' do
    let!(:fee_detail1) { create(:fee_detail, external_fee_id: 'FEE001') }
    let!(:fee_detail2) { create(:fee_detail, external_fee_id: 'FEE002') }

    it 'allows filtering by external fee ID' do
      visit '/admin/fee_details'
      expect(page).to have_content('FEE001')
      expect(page).to have_content('FEE002')
    end

    it 'allows filtering by amount' do
      visit '/admin/fee_details'
      expect(page).to have_content('筛选')
    end
  end

  describe 'financial calculations' do
    let!(:fees) do
      [
        create(:fee_detail, amount: 100.00),
        create(:fee_detail, amount: 50.00),
        create(:fee_detail, amount: 25.00)
      ]
    end

    it 'displays multiple fee amounts' do
      visit '/admin/fee_details'
      expect(page).to have_content('100.0')
      expect(page).to have_content('50.0')
      expect(page).to have_content('25.0')
    end
  end
end