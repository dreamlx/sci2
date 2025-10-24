# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Imports Authorization', type: :request do
  let!(:admin_user) { create(:admin_user, :admin) }
  let!(:super_admin_user) { create(:admin_user, :super_admin) }

  describe 'GET /admin/imports' do
    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies access to imports page' do
        get admin_imports_path
        expect(response).to redirect_to(admin_dashboard_path)
        follow_redirect!
        expect(response.body).to include('您没有权限访问数据导入功能')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows access to imports page' do
        get admin_imports_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /admin/imports/operation_histories' do
    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies access to operation histories' do
        get operation_histories_admin_imports_path
        expect(response).to redirect_to(admin_dashboard_path)
        follow_redirect!
        expect(response.body).to include('您没有权限访问数据导入功能')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows access to operation histories' do
        get operation_histories_admin_imports_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /admin/imports/import_operation_histories' do
    let(:file) { fixture_file_upload('files/test_operation_histories.csv', 'text/csv') }

    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies operation history import' do
        post import_operation_histories_admin_imports_path, params: { file: file }
        expect(response).to redirect_to(admin_dashboard_path)
        follow_redirect!
        expect(response.body).to include('您没有权限访问数据导入功能')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows operation history import' do
        post import_operation_histories_admin_imports_path, params: { file: file }
        # Response depends on file content, but should not be an authorization redirect
        expect(response).not_to redirect_to(admin_dashboard_path)
      end
    end
  end

  describe 'GET /admin/imports/new' do
    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies access to new import page' do
        get '/admin/imports/new', params: { resource: 'problem_codes' }
        expect(response).to redirect_to(admin_dashboard_path)
        follow_redirect!
        expect(response.body).to include('您没有权限访问数据导入功能')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows access to new import page' do
        get '/admin/imports/new', params: { resource: 'problem_codes' }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /admin/imports/import_problem_codes' do
    let(:file) { fixture_file_upload('files/test_problem_codes.csv', 'text/csv') }

    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies problem codes import' do
        post '/admin/imports/import_problem_codes', params: { file: file }
        expect(response).to redirect_to('/admin/imports/new?resource=problem_codes')
        follow_redirect!
        expect(response.body).to include('您没有权限访问数据导入功能')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows problem codes import' do
        post '/admin/imports/import_problem_codes', params: { file: file }
        # Response depends on file content, but should not be an authorization redirect
        expect(response).not_to redirect_to('/admin/imports/new?resource=problem_codes')
      end
    end
  end

  describe 'JSON API access' do
    context 'with admin user' do
      before { sign_in admin_user }

      it 'returns 403 for JSON requests' do
        get admin_imports_path, format: :json
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['code']).to eq(403)
        expect(json_response['message']).to include('您没有权限访问数据导入功能')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows JSON requests' do
        get admin_imports_path, format: :json
        expect(response).to have_http_status(:success)
      end
    end
  end
end
