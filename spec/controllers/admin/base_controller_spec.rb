# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::BaseController, type: :controller do
  describe 'class configuration' do
    it 'inherits from ApplicationController' do
      expect(described_class.superclass).to eq(ApplicationController)
    end

    it 'uses active_admin layout' do
      expect(described_class._layout).to eq('active_admin')
    end

    it 'has authenticate_admin_user! before_action' do
      callbacks = described_class._process_action_callbacks
      auth_callback = callbacks.find { |c| c.filter == :authenticate_admin_user! }
      expect(auth_callback).to be_present
    end
  end

  describe 'protected methods' do
    let(:controller_instance) { described_class.new }
    let(:admin_user) { AdminUser.create!(email: 'admin@test.com', password: 'password123') }

    describe '#current_admin_user' do
      it 'delegates to current_user from ApplicationController' do
        allow(controller_instance).to receive(:current_user).and_return(admin_user)

        expect(controller_instance.send(:current_admin_user)).to eq(admin_user)
      end
    end
  end
end
