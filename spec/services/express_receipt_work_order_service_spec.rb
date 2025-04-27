require 'rails_helper'

RSpec.describe ExpressReceiptWorkOrderService do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:work_order) { create(:express_receipt_work_order, reimbursement: reimbursement, status: 'received') }
  let(:service) { described_class.new(work_order, admin_user) }

  describe '#process' do
    context 'when processing is successful' do
      it 'updates work order status to processed' do
        expect { service.process }.to change { work_order.reload.status }.from('received').to('processed')
      end

      it 'creates operation history record' do
        expect { service.process }.to change(OperationHistory, :count).by(1)
      end

      it 'returns true' do
        expect(service.process).to be true
      end
    end

    context 'when processing fails' do
      before do
        allow(work_order).to receive(:process!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'does not update work order status' do
        expect { service.process rescue nil }.not_to change { work_order.reload.status }
      end

      it 'does not create operation history record' do
        expect { service.process rescue nil }.not_to change(OperationHistory, :count)
      end

      it 'returns false' do
        expect(service.process).to be false
      end
    end
  end

  describe '#complete' do
    before do
      work_order.update(status: 'processed')
    end

    context 'when completion is successful' do
      it 'updates work order status to completed' do
        expect { service.complete }.to change { work_order.reload.status }.from('processed').to('completed')
      end

      it 'creates operation history record' do
        expect { service.complete }.to change(OperationHistory, :count).by(1)
      end

      it 'returns true' do
        expect(service.complete).to be true
      end
    end

    context 'when completion fails' do
      before do
        allow(work_order).to receive(:complete!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'does not update work order status' do
        expect { service.complete rescue nil }.not_to change { work_order.reload.status }
      end

      it 'does not create operation history record' do
        expect { service.complete rescue nil }.not_to change(OperationHistory, :count)
      end

      it 'returns false' do
        expect(service.complete).to be false
      end
    end
  end
end