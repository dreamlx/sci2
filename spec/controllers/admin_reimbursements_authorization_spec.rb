# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Reimbursements Authorization', type: :request do
  let!(:admin_user) { create(:admin_user, :admin) }
  let!(:super_admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement) { create(:reimbursement) }

  describe 'GET /admin/reimbursements' do
    context 'with admin user' do
      before { sign_in admin_user }

      it 'allows access to index' do
        get admin_reimbursements_path
        expect(response).to have_http_status(:success)
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows access to index' do
        get admin_reimbursements_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /admin/reimbursements' do
    context 'with admin user' do
      before { sign_in admin_user }

      it 'allows creation' do
        post admin_reimbursements_path, params: {
          reimbursement: attributes_for(:reimbursement)
        }
        expect(response).to have_http_status(:found) # Redirect on success
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows creation' do
        post admin_reimbursements_path, params: {
          reimbursement: attributes_for(:reimbursement)
        }
        expect(response).to have_http_status(:found)
      end
    end
  end

  describe 'PUT /admin/reimbursements/:id/assign' do
    let!(:assignee) { create(:admin_user, :admin) }

    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies assignment' do
        put assign_admin_reimbursement_path(reimbursement), params: {
          assignee_id: assignee.id,
          notes: 'Test assignment'
        }
        expect(response).to redirect_to(admin_reimbursement_path(reimbursement))
        follow_redirect!
        expect(response.body).to include('您没有权限执行分配操作')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows assignment' do
        put assign_admin_reimbursement_path(reimbursement), params: {
          assignee_id: assignee.id,
          notes: 'Test assignment'
        }
        expect(response).to redirect_to(admin_reimbursement_path(reimbursement))
        follow_redirect!
        expect(response.body).to include('已分配给')
      end
    end
  end

  describe 'POST /admin/reimbursements/import' do
    let(:file) { fixture_file_upload('files/test_reimbursements.csv', 'text/csv') }

    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies import' do
        post import_admin_reimbursements_path, params: { file: file }
        expect(response).to redirect_to(new_import_admin_reimbursements_path)
        follow_redirect!
        expect(response.body).to include('您没有权限导入数据')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows import' do
        post import_admin_reimbursements_path, params: { file: file }
        # The response might be success or redirect depending on file content
        expect(response).not_to redirect_to(new_import_admin_reimbursements_path)
      end
    end
  end

  describe 'batch actions' do
    let!(:reimbursements) { create_list(:reimbursement, 3) }
    let!(:assignee) { create(:admin_user, :admin) }

    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies batch assignment' do
        post batch_action_admin_reimbursements_path, params: {
          batch_action: 'assign_to',
          collection_selection: reimbursements.map(&:id),
          assignee: assignee.id
        }
        expect(response).to redirect_to(admin_reimbursements_path)
        follow_redirect!
        expect(response.body).to include('您没有权限执行分配操作')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows batch assignment' do
        post batch_action_admin_reimbursements_path, params: {
          batch_action: 'assign_to',
          collection_selection: reimbursements.map(&:id),
          assignee: assignee.id
        }
        expect(response).to redirect_to(admin_reimbursements_path)
        follow_redirect!
        expect(response.body).to include('成功分配')
      end
    end
  end

  describe 'manual override actions' do
    context 'with admin user' do
      before { sign_in admin_user }

      it 'denies manual status changes' do
        put manual_set_pending_admin_reimbursement_path(reimbursement)
        expect(response).to redirect_to(admin_reimbursement_path(reimbursement))
        follow_redirect!
        expect(response.body).to include('您没有权限执行手动状态覆盖操作')
      end
    end

    context 'with super admin user' do
      before { sign_in super_admin_user }

      it 'allows manual status changes' do
        put manual_set_pending_admin_reimbursement_path(reimbursement)
        expect(response).to redirect_to(admin_reimbursement_path(reimbursement))
        follow_redirect!
        expect(response.body).to include('手动设置')
      end
    end
  end
end
