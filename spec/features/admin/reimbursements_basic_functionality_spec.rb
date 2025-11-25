# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reimbursements Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing reimbursements page' do
    it 'loads the page successfully' do
      visit '/admin/reimbursements'
      expect(page).to have_content('报销单管理')
      expect(page.status_code).to eq(200)
    end

    it 'displays the reimbursements table' do
      visit '/admin/reimbursements'
      expect(page).to have_content('筛选')
      expect(page).to have_content('每页显示')
    end

    it 'shows new reimbursement button' do
      visit '/admin/reimbursements'
      expect(page).to have_link('新建报销单')
    end
  end

  describe 'when there are no reimbursements' do
    it 'shows appropriate empty message' do
      visit '/admin/reimbursements'
      expect(page).to have_content('没有数据')
    end
  end

  describe 'when there are reimbursements' do
    let!(:reimbursement) { create(:reimbursement) }

    it 'displays reimbursement data' do
      visit '/admin/reimbursements'
      expect(page).to have_content(reimbursement.reimbursement_id)
    end

    it 'allows viewing individual reimbursement' do
      visit "/admin/reimbursements/#{reimbursement.id}"
      expect(page).to have_content('报销单详情')
      expect(page.status_code).to eq(200)
    end

    it 'allows editing reimbursement' do
      visit "/admin/reimbursements/#{reimbursement.id}/edit"
      expect(page).to have_content('编辑报销单')
      expect(page.status_code).to eq(200)
    end
  end

  describe 'creating new reimbursement' do
    it 'shows the new reimbursement form' do
      visit '/admin/reimbursements/new'
      expect(page).to have_content('新建报销单')
      expect(page.status_code).to eq(200)
    end

    it 'displays required form fields' do
      visit '/admin/reimbursements/new'
      expect(page).to have_field('reimbursement_reimbursement_id')
      expect(page).to have_field('reimbursement_company')
      expect(page).to have_field('reimbursement_total_amount')
    end
  end

  describe 'error handling' do
    it 'handles invalid reimbursement IDs gracefully' do
      visit '/admin/reimbursements/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles database errors gracefully' do
      allow(Reimbursement).to receive(:page).and_raise(StandardError.new('Database error'))

      visit '/admin/reimbursements'
      expect(page.status_code).to eq(500)
    end
  end
end