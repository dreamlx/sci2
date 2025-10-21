# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AttachmentUploadService, type: :service do
  let(:reimbursement) { create(:reimbursement) }
  let(:params) { { attachments: [fixture_file_upload('test.pdf', 'application/pdf')] } }
  let(:service) { described_class.new(reimbursement, params) }

  describe '#initialize' do
    it 'initializes with a reimbursement and params' do
      expect(service.reimbursement).to eq(reimbursement)
      expect(service.params).to eq(params)
    end
  end

  describe '#upload' do
    context 'with valid parameters' do
      it 'creates a new FeeDetail record' do
        expect { service.upload }.to change(FeeDetail, :count).by(1)
      end

      it 'attaches the file to the new FeeDetail record' do
        service.upload
        fee_detail = FeeDetail.last
        expect(fee_detail.attachments).to be_attached
      end

      it 'returns a successful result object' do
        result = service.upload
        expect(result[:success]).to be(true)
        expect(result[:fee_detail]).to be_a(FeeDetail)
      end
    end

    context 'when saving fails' do
      before do
        allow_any_instance_of(FeeDetail).to receive(:save).and_return(false)
        allow_any_instance_of(FeeDetail).to receive_message_chain(:errors, :full_messages).and_return(['Error'])
      end

      it 'does not create a new FeeDetail record' do
        expect { service.upload }.not_to change(FeeDetail, :count)
      end

      it 'returns a failure result object' do
        result = service.upload
        expect(result[:success]).to be(false)
        expect(result[:error]).to include('Error')
      end
    end
  end
end
