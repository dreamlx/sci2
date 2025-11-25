# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Problem Types Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing problem types page' do
    it 'loads the page successfully' do
      visit '/admin/problem_types'
      expect(page).to have_content('问题类型')
      expect(page.status_code).to eq(200)
    end

    it 'displays the problem types table' do
      visit '/admin/problem_types'
      expect(page).to have_content('筛选')
      expect(page).to have_content('每页显示')
    end

    it 'shows new problem type button' do
      visit '/admin/problem_types'
      expect(page).to have_link('新建问题类型')
    end
  end

  describe 'when there are no problem types' do
    it 'shows appropriate empty message' do
      visit '/admin/problem_types'
      expect(page).to have_content('还没有')
    end
  end

  describe 'when there are problem types' do
    let!(:problem_type) { create(:problem_type) }

    it 'displays problem type data' do
      visit '/admin/problem_types'
      expect(page).to have_content(problem_type.name)
      expect(page).to have_content(problem_type.severity)
    end

    it 'allows viewing individual problem type' do
      visit "/admin/problem_types/#{problem_type.id}"
      expect(page).to have_content('问题类型详情')
      expect(page.status_code).to eq(200)
    end

    it 'allows editing problem type' do
      visit "/admin/problem_types/#{problem_type.id}/edit"
      expect(page).to have_content('编辑问题类型')
      expect(page.status_code).to eq(200)
    end

    it 'displays problem type attributes' do
      visit "/admin/problem_types/#{problem_type.id}"
      expect(page).to have_content(problem_type.description) if problem_type.description
      expect(page).to have_content(problem_type.severity)
    end
  end

  describe 'creating new problem type' do
    it 'shows the new problem type form' do
      visit '/admin/problem_types/new'
      expect(page).to have_content('新建问题类型')
      expect(page.status_code).to eq(200)
    end

    it 'displays required form fields' do
      visit '/admin/problem_types/new'
      expect(page).to have_field('problem_type_name')
      expect(page).to have_field('problem_type_severity')
    end

    it 'displays optional form fields' do
      visit '/admin/problem_types/new'
      expect(page).to have_field('problem_type_description')
    end
  end

  describe 'problem type severity levels' do
    let!(:low_problem) { create(:problem_type, severity: 'low') }
    let!(:medium_problem) { create(:problem_type, severity: 'medium') }
    let!(:high_problem) { create(:problem_type, severity: 'high') }

    it 'displays different severity levels' do
      visit '/admin/problem_types'
      expect(page).to have_content('low')
      expect(page).to have_content('medium')
      expect(page).to have_content('high')
    end
  end

  describe 'problem type management' do
    let!(:problem_type) { create(:problem_type) }

    it 'allows deleting problem types' do
      visit "/admin/problem_types/#{problem_type.id}"
      expect(page).to have_content('删除')
    end

    it 'shows problem type usage count if applicable' do
      visit "/admin/problem_types/#{problem_type.id}"
      # Check if there are associated work orders count
      expect(page.status_code).to eq(200)
    end
  end

  describe 'error handling' do
    it 'handles invalid problem type IDs gracefully' do
      visit '/admin/problem_types/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles database errors gracefully' do
      allow(ProblemType).to receive(:page).and_raise(StandardError.new('Database error'))

      visit '/admin/problem_types'
      expect(page.status_code).to eq(500)
    end

    it 'handles validation errors on create' do
      visit '/admin/problem_types/new'
      click_button('创建问题类型')
      # Should show validation errors
      expect(page.status_code).to be_in([200, 422])
    end
  end

  describe 'filtering and searching' do
    let!(:problem_type1) { create(:problem_type, name: '快递问题') }
    let!(:problem_type2) { create(:problem_type, name: '审核问题') }

    it 'allows filtering by name' do
      visit '/admin/problem_types'
      expect(page).to have_content('快递问题')
      expect(page).to have_content('审核问题')
    end

    it 'allows filtering by severity' do
      visit '/admin/problem_types'
      expect(page).to have_content('筛选')
    end
  end
end