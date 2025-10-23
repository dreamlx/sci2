# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin::Users Authorization", type: :request do
  let!(:admin_user) { create(:admin_user, :admin) }
  let!(:super_admin_user) { create(:admin_user, :super_admin) }
  let!(:test_user) { create(:admin_user, :admin) }

  describe "GET /admin/admin_users" do
    context "with admin user" do
      before { sign_in admin_user }

      it "denies access to admin users list" do
        get admin_admin_users_path
        expect(response).to redirect_to(admin_dashboard_path)
        follow_redirect!
        expect(response.body).to include("您没有权限查看管理员用户列表")
      end
    end

    context "with super admin user" do
      before { sign_in super_admin_user }

      it "allows access to admin users list" do
        get admin_admin_users_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /admin/admin_users" do
    context "with admin user" do
      before { sign_in admin_user }

      it "denies user creation" do
        post admin_admin_users_path, params: {
          admin_user: attributes_for(:admin_user, :admin)
        }
        expect(response).to redirect_to(admin_dashboard_path)
        follow_redirect!
        expect(response.body).to include("您没有权限创建或修改管理员用户")
      end
    end

    context "with super admin user" do
      before { sign_in super_admin_user }

      it "allows user creation" do
        post admin_admin_users_path, params: {
          admin_user: attributes_for(:admin_user, :admin)
        }
        expect(response).to have_http_status(:found)
      end
    end
  end

  describe "PUT /admin/admin_users/:id/soft_delete" do
    context "with admin user" do
      before { sign_in admin_user }

      it "denies soft delete" do
        put soft_delete_admin_admin_user_path(test_user)
        expect(response).to redirect_to(admin_admin_user_path(test_user))
        follow_redirect!
        expect(response.body).to include("您没有权限删除或恢复管理员用户")
      end
    end

    context "with super admin user" do
      before { sign_in super_admin_user }

      it "allows soft delete" do
        put soft_delete_admin_admin_user_path(test_user)
        expect(response).to redirect_to(admin_admin_user_path(test_user))
        follow_redirect!
        expect(response.body).to include("已软删除")
      end
    end
  end

  describe "batch actions" do
    let!(:users) { create_list(:admin_user, 3, :admin) }

    context "with admin user" do
      before { sign_in admin_user }

      it "denies batch soft delete" do
        post batch_action_admin_admin_users_path, params: {
          batch_action: '软删除',
          collection_selection: users.map(&:id)
        }
        expect(response).to redirect_to(admin_admin_users_path)
        follow_redirect!
        expect(response.body).to include("您没有权限执行批量操作")
      end
    end

    context "with super admin user" do
      before { sign_in super_admin_user }

      it "allows batch soft delete" do
        post batch_action_admin_admin_users_path, params: {
          batch_action: '软删除',
          collection_selection: users.map(&:id)
        }
        expect(response).to redirect_to(admin_admin_users_path)
        follow_redirect!
        expect(response.body).to include("已软删除")
      end
    end
  end

  describe "self-update permissions" do
    context "when admin user updates their own profile" do
      before { sign_in admin_user }

      it "allows updating own basic info" do
        put admin_admin_user_path(admin_user), params: {
          admin_user: {
            name: "Updated Name",
            email: admin_user.email,
            telephone: "1234567890"
          }
        }
        expect(response).to redirect_to(admin_admin_user_path(admin_user))
        admin_user.reload
        expect(admin_user.name).to eq("Updated Name")
      end

      it "prevents updating own role" do
        put admin_admin_user_path(admin_user), params: {
          admin_user: {
            role: "super_admin",
            email: admin_user.email
          }
        }
        expect(response).to have_http_status(:found)
        admin_user.reload
        expect(admin_user.role).not_to eq("super_admin")
      end
    end
  end
end