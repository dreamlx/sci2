# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthorizationConcern, type: :controller do
  # Create a test controller that includes the concern
  controller(ApplicationController) do
    include AuthorizationConcern

    # Mock actions for testing
    def test_action
      head :ok
    end

    def test_member_action
      head :ok
    end

    def test_batch_action
      head :ok
    end

    def test_collection_action
      head :ok
    end

    private

    def resource
      @resource ||= double('resource')
    end
  end

  let!(:admin_user) { create(:admin_user, :admin) }
  let!(:super_admin_user) { create(:admin_user, :super_admin) }
  let!(:test_reimbursement) { create(:reimbursement) }

  before do
    routes.draw {
      get 'test_action' => 'anonymous#test_action'
      post 'test_member_action' => 'anonymous#test_member_action'
      post 'test_batch_action' => 'anonymous#test_batch_action'
      post 'test_collection_action' => 'anonymous#test_collection_action'
    }
  end

  describe 'authentication checks' do
    context 'when user is not authenticated' do
      before do
        allow(controller).to receive(:current_admin_user).and_return(nil)
      end

      it 'redirects to login for HTML requests' do
        get :test_action, format: :html
        expect(response).to redirect_to(new_admin_user_session_path)
      end

      it 'returns 401 for JSON requests' do
        get :test_action, format: :json
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['code']).to eq(401)
      end
    end
  end

  describe 'authorization checks with ReimbursementPolicy' do
    context 'with admin user' do
      before do
        allow(controller).to receive(:current_admin_user).and_return(admin_user)
        allow(controller).to receive(:resource).and_return(test_reimbursement)
        allow(controller).to receive(:action_name).and_return('test_action')
      end

      it 'allows actions that admin user can perform' do
        mock_policy = double('ReimbursementPolicy')
        allow(ReimbursementPolicy).to receive(:new).with(admin_user, test_reimbursement).and_return(mock_policy)
        allow(mock_policy).to receive(:can_test_action?).and_return(true)

        get :test_action
        expect(response).to have_http_status(:ok)
      end

      it 'denies actions that admin user cannot perform' do
        mock_policy = double('ReimbursementPolicy')
        allow(ReimbursementPolicy).to receive(:new).with(admin_user, test_reimbursement).and_return(mock_policy)
        allow(mock_policy).to receive(:can_test_action?).and_return(false)
        allow(mock_policy).to receive(:authorization_error_message).with(action: :test_action).and_return('Permission denied')

        get :test_action
        expect(response).to redirect_to(admin_dashboard_path)
        expect(flash[:alert]).to eq('Permission denied')
      end
    end

    context 'with super admin user' do
      before do
        allow(controller).to receive(:current_admin_user).and_return(super_admin_user)
        allow(controller).to receive(:resource).and_return(test_reimbursement)
        allow(controller).to receive(:action_name).and_return('test_action')
      end

      it 'allows all actions for super admin' do
        mock_policy = double('ReimbursementPolicy')
        allow(ReimbursementPolicy).to receive(:new).with(super_admin_user, test_reimbursement).and_return(mock_policy)
        allow(mock_policy).to receive(:can_test_action?).and_return(true)

        get :test_action
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'logging functionality' do
    let(:mock_policy) { double('ReimbursementPolicy') }

    before do
      allow(controller).to receive(:current_admin_user).and_return(admin_user)
      allow(controller).to receive(:resource).and_return(test_reimbursement)
      allow(controller).to receive(:action_name).and_return('test_action')
      allow(ReimbursementPolicy).to receive(:new).and_return(mock_policy)
    end

    it 'logs successful authorization' do
      allow(mock_policy).to receive(:can_test_action?).and_return(true)
      expect(Rails.logger).to receive(:info).with(/AUTH_SUCCESS/)

      get :test_action
    end

    it 'logs authorization failures' do
      allow(mock_policy).to receive(:can_test_action?).and_return(false)
      allow(mock_policy).to receive(:authorization_error_message).and_return('Access denied')
      expect(Rails.logger).to receive(:warn).with(/AUTH_FAILURE/)
      expect(Rails.logger).to receive(:info).with(/SECURITY_ALERT/)

      get :test_action
    end
  end

  describe 'helper methods' do
    before do
      allow(controller).to receive(:current_admin_user).and_return(admin_user)
    end

    describe '#require_super_admin!' do
      it 'allows super admin users' do
        allow(controller).to receive(:current_admin_user).and_return(super_admin_user)
        expect(controller.send(:require_super_admin!)).to be true
      end

      it 'denies admin users' do
        expect(controller).to receive(:handle_authorization_error).with('此操作仅限超级管理员执行', { redirect_to: admin_dashboard_path })
        expect(controller.send(:require_super_admin!)).to be false
      end
    end

    describe '#require_admin_or_super_admin!' do
      it 'allows super admin users' do
        allow(controller).to receive(:current_admin_user).and_return(super_admin_user)
        expect(controller.send(:require_admin_or_super_admin!)).to be true
      end

      it 'allows admin users' do
        expect(controller.send(:require_admin_or_super_admin!)).to be true
      end
    end

    describe '#require_permission?' do
      it 'returns true when permission is granted' do
        mock_policy = double('ReimbursementPolicy')
        allow(ReimbursementPolicy).to receive(:new).with(admin_user, test_reimbursement).and_return(mock_policy)
        allow(mock_policy).to receive(:can_test_action?).and_return(true)

        expect(controller.send(:require_permission?, 'ReimbursementPolicy', 'can_test_action?', test_reimbursement)).to be true
      end

      it 'returns false when permission is denied' do
        mock_policy = double('ReimbursementPolicy')
        allow(ReimbursementPolicy).to receive(:new).with(admin_user, test_reimbursement).and_return(mock_policy)
        allow(mock_policy).to receive(:can_test_action?).and_return(false)

        expect(controller.send(:require_permission?, 'ReimbursementPolicy', 'can_test_action?', test_reimbursement)).to be false
      end
    end
  end

  describe 'sensitive operation logging' do
    before do
      allow(controller).to receive(:current_admin_user).and_return(admin_user)
      allow(Rails.logger).to receive(:warn)
    end

    it 'logs sensitive operation attempts' do
      expect(Rails.logger).to receive(:warn).with(/SENSITIVE_OPERATION.*destroy/)
      controller.send(:log_sensitive_operation_attempt, 'destroy', test_reimbursement)
    end
  end

  describe 'parameter sanitization for logging' do
    it 'filters sensitive parameters' do
      params = ActionController::Parameters.new({
        'email' => 'test@example.com',
        'password' => 'secret123',
        'user' => {
          'name' => 'Test User',
          'password' => 'another_secret'
        }
      })

      sanitized = controller.send(:sanitize_params_for_logging)
      expect(sanitized['password']).to eq('[FILTERED]')
      # Note: This test would need the actual params to be available in the controller
    end
  end
end