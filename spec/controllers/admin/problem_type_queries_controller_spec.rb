# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::ProblemTypeQueriesController, type: :controller do
  let(:admin_user) { AdminUser.create!(email: 'admin@test.com', password: 'password123') }

  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: 'INV-001',
      document_name: '测试报销单',
      status: 'processing',
      is_electronic: true
    )
  end

  let(:fee_type) do
    FeeType.create!(
      code: '00',
      name: '月度交通费',
      reimbursement_type_code: '个人',
      meeting_type_code: '无',
      expense_type_code: '交通',
      active: true
    )
  end

  let(:fee_detail) do
    FeeDetail.create!(
      external_fee_id: 'FEE001',
      document_number: reimbursement.invoice_number,
      fee_type: fee_type.name,
      amount: 100.0,
      fee_date: Date.today,
      verification_status: 'pending'
    )
  end

  let(:problem_type) do
    ProblemType.create!(
      issue_code: 'P001',
      title: '燃油费行程问题',
      sop_description: '检查燃油费是否与行程匹配',
      standard_handling: '要求提供详细行程单',
      fee_type: fee_type,
      active: true
    )
  end

  before do
    sign_in admin_user
    problem_type
  end

  describe 'GET #for_fee_details' do
    context 'with valid parameters' do
      it 'returns problem types as JSON' do
        get :for_fee_details, params: {
          reimbursement_id: reimbursement.id,
          fee_detail_ids: fee_detail.id.to_s
        }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
      end

      it 'includes expected attributes in response' do
        get :for_fee_details, params: {
          reimbursement_id: reimbursement.id,
          fee_detail_ids: fee_detail.id.to_s
        }

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)

        if json_response.any?
          first_item = json_response.first
          expect(first_item).to have_key('id')
          expect(first_item).to have_key('title')
          expect(first_item).to have_key('sop_description')
        end
      end

      it 'accepts multiple fee detail IDs' do
        fee_detail2 = FeeDetail.create!(
          external_fee_id: 'FEE002',
          document_number: reimbursement.invoice_number,
          fee_type: fee_type.name,
          amount: 200.0,
          fee_date: Date.today,
          verification_status: 'pending'
        )

        get :for_fee_details, params: {
          reimbursement_id: reimbursement.id,
          fee_detail_ids: "#{fee_detail.id},#{fee_detail2.id}"
        }

        expect(response).to have_http_status(:success)
      end
    end

    context 'with missing reimbursement_id' do
      it 'returns bad request error' do
        get :for_fee_details, params: {
          fee_detail_ids: fee_detail.id.to_s
        }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Missing reimbursement_id or fee_detail_ids')
      end
    end

    context 'with missing fee_detail_ids' do
      it 'returns bad request error' do
        get :for_fee_details, params: {
          reimbursement_id: reimbursement.id
        }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Missing reimbursement_id or fee_detail_ids')
      end
    end

    context 'with invalid reimbursement_id' do
      it 'returns bad request error' do
        get :for_fee_details, params: {
          reimbursement_id: 99999,
          fee_detail_ids: fee_detail.id.to_s
        }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when not authenticated' do
      before do
        sign_out admin_user
      end

      it 'redirects to sign in' do
        get :for_fee_details, params: {
          reimbursement_id: reimbursement.id,
          fee_detail_ids: fee_detail.id.to_s
        }

        expect(response).to redirect_to(new_admin_user_session_path)
      end
    end
  end
end
