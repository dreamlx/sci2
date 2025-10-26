# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: 'OK'
    end

    def test_access_denied
      access_denied(StandardError.new('Test'))
    end
  end

  let(:admin_user) { AdminUser.create!(email: 'admin@test.com', password: 'password123') }

  describe '#set_locale' do
    it 'sets locale to zh-CN' do
      get :index
      expect(I18n.locale).to eq(:'zh-CN')
    end

    it 'is called before action' do
      expect(controller).to receive(:set_locale).and_call_original
      get :index
    end
  end

  describe '#access_denied' do
    before do
      routes.draw { get 'test_access_denied' => 'anonymous#test_access_denied' }
    end

    it 'redirects to admin dashboard' do
      get :test_access_denied
      expect(response).to redirect_to(admin_dashboard_path)
    end

    it 'sets alert message' do
      get :test_access_denied
      expect(flash[:alert]).to eq('您没有执行此操作的权限。')
    end
  end

  describe '#redirect_to_admin' do
    before do
      routes.draw { get 'index' => 'anonymous#index' }
    end

    it 'redirects to admin root path' do
      expect(controller).to receive(:redirect_to).with(admin_root_path)
      controller.send(:redirect_to_admin)
    end
  end

  describe '#current_user' do
    context 'when admin user is authenticated' do
      before do
        allow(controller).to receive(:warden).and_return(
          double(authenticate: admin_user)
        )
      end

      it 'returns current_admin_user' do
        expect(controller.send(:current_user)).to eq(admin_user)
      end
    end

    context 'when no user is authenticated' do
      before do
        allow(controller).to receive(:warden).and_return(
          double(authenticate: nil)
        )
      end

      it 'returns nil' do
        expect(controller.send(:current_user)).to be_nil
      end
    end
  end

  describe '#current_admin_user' do
    context 'when admin user is authenticated' do
      before do
        allow(controller).to receive(:warden).and_return(
          double(authenticate: admin_user)
        )
      end

      it 'returns authenticated admin user' do
        expect(controller.send(:current_admin_user)).to eq(admin_user)
      end

      it 'caches the result' do
        warden = double(authenticate: admin_user)
        allow(controller).to receive(:warden).and_return(warden)

        expect(warden).to receive(:authenticate).once.and_return(admin_user)

        controller.send(:current_admin_user)
        controller.send(:current_admin_user)
      end
    end
  end

  describe '#authenticate_admin_user!' do
    before do
      routes.draw { get 'index' => 'anonymous#index' }
    end

    context 'when admin user is not authenticated' do
      before do
        allow(controller).to receive(:current_admin_user).and_return(nil)
      end

      it 'calls redirect_to with new_admin_user_session_path' do
        expect(controller).to receive(:redirect_to).with(new_admin_user_session_path)
        controller.send(:authenticate_admin_user!)
      end
    end

    context 'when admin user is authenticated' do
      before do
        allow(controller).to receive(:current_admin_user).and_return(admin_user)
      end

      it 'does not call redirect_to' do
        expect(controller).not_to receive(:redirect_to)
        controller.send(:authenticate_admin_user!)
      end
    end
  end

  describe 'inheritance' do
    it 'inherits from ActionController::Base' do
      expect(described_class.superclass).to eq(ActionController::Base)
    end
  end
end
