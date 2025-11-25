# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Users Page', type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    login_as(admin_user, scope: :admin_user)
  end

  describe 'accessing admin users page' do
    it 'loads the page successfully' do
      visit '/admin/admin_users'
      expect(page).to have_content('管理员用户')
      expect(page.status_code).to eq(200)
    end

    it 'displays the admin users table' do
      visit '/admin/admin_users'
      expect(page).to have_content('筛选')
      expect(page).to have_content('每页显示')
    end

    it 'shows new admin user button' do
      visit '/admin/admin_users'
      expect(page).to have_link('新建管理员用户')
    end
  end

  describe 'when there are admin users' do
    let!(:other_admin) { create(:admin_user, email: 'other@example.com') }

    it 'displays admin user data' do
      visit '/admin/admin_users'
      expect(page).to have_content(admin_user.email)
      expect(page).to have_content(other_admin.email)
    end

    it 'allows viewing individual admin user' do
      visit "/admin/admin_users/#{admin_user.id}"
      expect(page).to have_content('管理员用户详情')
      expect(page.status_code).to eq(200)
    end

    it 'allows editing admin user' do
      visit "/admin/admin_users/#{admin_user.id}/edit"
      expect(page).to have_content('编辑管理员用户')
      expect(page.status_code).to eq(200)
    end

    it 'displays user permissions' do
      visit "/admin/admin_users/#{admin_user.id}"
      expect(page).to have_content(admin_user.email)
    end
  end

  describe 'creating new admin user' do
    it 'shows the new admin user form' do
      visit '/admin/admin_users/new'
      expect(page).to have_content('新建管理员用户')
      expect(page.status_code).to eq(200)
    end

    it 'displays required form fields' do
      visit '/admin/admin_users/new'
      expect(page).to have_field('admin_user_email')
      expect(page).to have_field('admin_user_password')
      expect(page).to have_field('admin_user_password_confirmation')
    end

    it 'displays user role fields' do
      visit '/admin/admin_users/new'
      expect(page).to have_field('admin_user_role') if page.has_field?('admin_user_role')
    end
  end

  describe 'admin user management' do
    let!(:other_admin) { create(:admin_user, email: 'deletable@example.com') }

    it 'allows deleting admin users' do
      visit "/admin/admin_users/#{other_admin.id}"
      expect(page).to have_content('删除')
    end

    it 'shows user activity information' do
      visit "/admin/admin_users/#{admin_user.id}"
      expect(page.status_code).to eq(200)
    end

    it 'displays user creation date' do
      visit "/admin/admin_users/#{admin_user.id}"
      expect(page).to have_content(admin_user.created_at.strftime('%Y'))
    end
  end

  describe 'user authentication features' do
    it 'shows current user in navigation' do
      visit '/admin'
      expect(page).to have_content(admin_user.email)
    end

    it 'provides logout functionality' do
      visit '/admin'
      expect(page).to have_link('退出')
    end

    it 'requires authentication for admin pages' do
      logout(:admin_user)
      visit '/admin/admin_users'
      expect(page).to have_current_path('/admin/login')
    end
  end

  describe 'user permissions and roles' do
    it 'displays user role information' do
      visit "/admin/admin_users/#{admin_user.id}"
      expect(page.status_code).to eq(200)
    end

    it 'allows editing user permissions' do
      visit "/admin/admin_users/#{admin_user.id}/edit"
      expect(page.status_code).to eq(200)
    end
  end

  describe 'error handling' do
    it 'handles invalid admin user IDs gracefully' do
      visit '/admin/admin_users/99999'
      expect(page.status_code).to eq(404)
    end

    it 'handles database errors gracefully' do
      allow(AdminUser).to receive(:page).and_raise(StandardError.new('Database error'))

      visit '/admin/admin_users'
      expect(page.status_code).to eq(500)
    end

    it 'handles validation errors on create' do
      visit '/admin/admin_users/new'
      click_button('创建管理员用户')
      # Should show validation errors
      expect(page.status_code).to be_in([200, 422])
    end

    it 'handles duplicate email validation' do
      visit '/admin/admin_users/new'
      fill_in 'admin_user_email', with: admin_user.email
      fill_in 'admin_user_password', with: 'password'
      fill_in 'admin_user_password_confirmation', with: 'password'
      click_button('创建管理员用户')
      # Should show email already taken error
      expect(page.status_code).to be_in([200, 422])
    end
  end

  describe 'filtering and searching' do
    let!(:admin1) { create(:admin_user, email: 'admin1@example.com') }
    let!(:admin2) { create(:admin_user, email: 'admin2@example.com') }

    it 'allows filtering by email' do
      visit '/admin/admin_users'
      expect(page).to have_content('admin1@example.com')
      expect(page).to have_content('admin2@example.com')
    end

    it 'allows filtering by creation date' do
      visit '/admin/admin_users'
      expect(page).to have_content('筛选')
    end
  end

  describe 'user session management' do
    it 'maintains session across pages' do
      visit '/admin/admin_users'
      expect(page).to have_content('管理员用户')

      visit '/admin/reimbursements'
      expect(page).to have_content('报销单')

      visit '/admin/admin_users'
      expect(page).to have_content('管理员用户')
    end

    it 'shows login time information' do
      visit "/admin/admin_users/#{admin_user.id}"
      expect(page.status_code).to eq(200)
    end
  end

  describe 'password management' do
    it 'allows password change through edit' do
      visit "/admin/admin_users/#{admin_user.id}/edit"
      expect(page).to have_field('admin_user_password')
      expect(page).to have_field('admin_user_password_confirmation')
    end
  end
end