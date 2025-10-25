# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderFeeDetailRepository do
  let(:work_order) { create(:audit_work_order) }
  let(:work_order2) { create(:express_receipt_work_order) }
  let(:fee_type) { create(:fee_type) }
  let(:fee_detail1) do
    create(:fee_detail,
           amount: BigDecimal('100.00'))
  end
  let(:fee_detail2) do
    create(:fee_detail,
           amount: BigDecimal('200.00'))
  end

  let!(:association1) do
    create(:work_order_fee_detail,
           work_order: work_order,
           fee_detail: fee_detail1)
  end

  let!(:association2) do
    create(:work_order_fee_detail,
           work_order: work_order,
           fee_detail: fee_detail2)
  end

  describe '.find' do
    it 'finds association by id' do
      result = described_class.find(association1.id)
      expect(result).to eq(association1)
    end

    it 'returns nil when record not found' do
      result = described_class.find(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'finds association by id' do
      result = described_class.find_by_id(association1.id)
      expect(result).to eq(association1)
    end

    it 'returns nil when record not found' do
      result = described_class.find_by_id(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_ids' do
    it 'finds multiple associations by ids' do
      results = described_class.find_by_ids([association1.id, association2.id])
      expect(results.pluck(:id)).to contain_exactly(association1.id, association2.id)
    end

    it 'returns empty array for invalid ids' do
      results = described_class.find_by_ids([99999, 88888])
      expect(results).to be_empty
    end
  end

  describe '.by_work_order' do
    it 'finds all associations for a work order' do
      results = described_class.by_work_order(work_order.id)
      expect(results.pluck(:id)).to contain_exactly(association1.id, association2.id)
    end

    it 'returns empty array when no associations found' do
      results = described_class.by_work_order(99999)
      expect(results).to be_empty
    end
  end

  describe '.for_work_order' do
    it 'finds all associations for a work order object' do
      results = described_class.for_work_order(work_order)
      expect(results.pluck(:id)).to contain_exactly(association1.id, association2.id)
    end
  end

  describe '.find_fee_details_by_work_order' do
    it 'finds all fee details for a work order' do
      results = described_class.find_fee_details_by_work_order(work_order.id)
      expect(results.map(&:id)).to contain_exactly(fee_detail1.id, fee_detail2.id)
    end

    it 'returns empty array when no fee details found' do
      results = described_class.find_fee_details_by_work_order(99999)
      expect(results).to be_empty
    end

    it 'eager loads fee_detail association' do
      results = described_class.find_fee_details_by_work_order(work_order.id)
      expect { results.first.reimbursement }.not_to raise_error
    end
  end

  describe '.by_fee_detail' do
    it 'finds all associations for a fee detail' do
      results = described_class.by_fee_detail(fee_detail1.id)
      expect(results.pluck(:id)).to contain_exactly(association1.id)
    end

    it 'returns empty array when no associations found' do
      results = described_class.by_fee_detail(99999)
      expect(results).to be_empty
    end
  end

  describe '.find_work_orders_by_fee_detail' do
    it 'finds all work orders for a fee detail' do
      results = described_class.find_work_orders_by_fee_detail(fee_detail1.id)
      expect(results.map(&:id)).to contain_exactly(work_order.id)
    end

    it 'returns empty array when no work orders found' do
      results = described_class.find_work_orders_by_fee_detail(99999)
      expect(results).to be_empty
    end
  end

  describe '.by_work_order_type' do
    let!(:association3) do
      create(:work_order_fee_detail,
             work_order: work_order2,
             fee_detail: fee_detail1)
    end

    it 'finds associations for specific work order type' do
      results = described_class.by_work_order_type('ExpressReceiptWorkOrder')
      expect(results.pluck(:id)).to include(association3.id)
    end
  end

  describe '.create_association' do
    let(:fee_detail3) { create(:fee_detail) }

    it 'creates new association' do
      expect do
        described_class.create_association(
          work_order_id: work_order2.id,
          fee_detail_id: fee_detail3.id
        )
      end.to change(WorkOrderFeeDetail, :count).by(1)
    end

    it 'returns created association' do
      result = described_class.create_association(
        work_order_id: work_order2.id,
        fee_detail_id: fee_detail3.id
      )
      expect(result).to be_a(WorkOrderFeeDetail)
      expect(result.work_order_id).to eq(work_order2.id)
      expect(result.fee_detail_id).to eq(fee_detail3.id)
    end

    it 'prevents duplicate associations' do
      described_class.create_association(
        work_order_id: work_order2.id,
        fee_detail_id: fee_detail3.id
      )

      result = described_class.create_association(
        work_order_id: work_order2.id,
        fee_detail_id: fee_detail3.id
      )
      expect(result.persisted?).to be false
    end
  end

  describe '.remove_association' do
    it 'removes existing association' do
      expect do
        described_class.remove_association(
          work_order_id: work_order.id,
          fee_detail_id: fee_detail1.id
        )
      end.to change(WorkOrderFeeDetail, :count).by(-1)
    end

    it 'returns nil when association not found' do
      result = described_class.remove_association(
        work_order_id: 99999,
        fee_detail_id: 88888
      )
      expect(result).to be_nil
    end
  end

  describe '.batch_associate' do
    let(:fee_detail3) { create(:fee_detail) }
    let(:fee_detail4) { create(:fee_detail) }

    it 'creates multiple associations' do
      expect do
        described_class.batch_associate(
          work_order_id: work_order2.id,
          fee_detail_ids: [fee_detail3.id, fee_detail4.id]
        )
      end.to change(WorkOrderFeeDetail, :count).by(2)
    end

    it 'returns array of created associations' do
      results = described_class.batch_associate(
        work_order_id: work_order2.id,
        fee_detail_ids: [fee_detail3.id, fee_detail4.id]
      )
      expect(results.count).to eq(2)
      expect(results.all? { |r| r.is_a?(WorkOrderFeeDetail) }).to be true
    end
  end

  describe '.count_fee_details' do
    it 'counts fee details for work order' do
      count = described_class.count_fee_details(work_order.id)
      expect(count).to eq(2)
    end

    it 'returns zero when no fee details' do
      count = described_class.count_fee_details(work_order2.id)
      expect(count).to eq(0)
    end
  end

  describe '.count_work_orders' do
    let!(:association3) do
      create(:work_order_fee_detail,
             work_order: work_order2,
             fee_detail: fee_detail1)
    end

    it 'counts work orders for fee detail' do
      count = described_class.count_work_orders(fee_detail1.id)
      expect(count).to eq(2)
    end

    it 'returns zero when no work orders' do
      count = described_class.count_work_orders(fee_detail2.id)
      expect(count).to eq(1)
    end
  end

  describe '.total_amount_for_work_order' do
    it 'calculates total amount for work order' do
      total = described_class.total_amount_for_work_order(work_order.id)
      expect(total).to eq(300.0)
    end

    it 'returns zero when no fee details' do
      total = described_class.total_amount_for_work_order(work_order2.id)
      expect(total).to eq(0)
    end
  end

  describe '.group_by_fee_type' do
    it 'groups fee details by fee type' do
      results = described_class.group_by_fee_type(work_order.id)
      expect(results.count).to be >= 1
    end
  end

  describe '.exists?' do
    it 'returns true when association exists' do
      expect(described_class.exists?(id: association1.id)).to be true
    end

    it 'returns false when association does not exist' do
      expect(described_class.exists?(id: 99999)).to be false
    end
  end

  describe '.exists_by_id?' do
    it 'returns true when association exists' do
      expect(described_class.exists_by_id?(association1.id)).to be true
    end

    it 'returns false when association does not exist' do
      expect(described_class.exists_by_id?(99999)).to be false
    end
  end

  describe '.association_exists?' do
    it 'returns true when association exists' do
      expect(described_class.association_exists?(
               work_order_id: work_order.id,
               fee_detail_id: fee_detail1.id
             )).to be true
    end

    it 'returns false when association does not exist' do
      expect(described_class.association_exists?(
               work_order_id: 99999,
               fee_detail_id: 88888
             )).to be false
    end
  end

  describe '.with_associations' do
    it 'includes all associations' do
      results = described_class.with_associations
      expect { results.first.work_order }.not_to raise_error
      expect { results.first.fee_detail }.not_to raise_error
    end
  end

  describe '.optimized_list' do
    it 'returns optimized query with associations' do
      results = described_class.optimized_list
      expect { results.first.work_order }.not_to raise_error
      expect { results.first.fee_detail }.not_to raise_error
    end
  end

  describe '.select_fields' do
    it 'selects specific fields' do
      results = described_class.select_fields(%i[id work_order_id])
      expect(results.first.attributes.keys).to include('id', 'work_order_id')
    end
  end

  describe '.page' do
    before do
      3.times do |i|
        create(:work_order_fee_detail,
               work_order: work_order,
               fee_detail: create(:fee_detail))
      end
    end

    it 'paginates results with default per_page' do
      results = described_class.page(1, 2)
      expect(results.count).to eq(2)
    end

    it 'returns second page of results' do
      results = described_class.page(2, 2)
      expect(results.count).to be >= 1
    end
  end

  describe '.where' do
    it 'finds associations matching conditions' do
      results = described_class.where(work_order_id: work_order.id)
      expect(results.pluck(:id)).to contain_exactly(association1.id, association2.id)
    end
  end

  describe '.where_not' do
    it 'finds associations not matching conditions' do
      results = described_class.where_not(work_order_id: work_order.id)
      expect(results.pluck(:id)).not_to include(association1.id, association2.id)
    end
  end

  describe '.delete_all' do
    it 'deletes all records matching conditions' do
      expect do
        described_class.delete_all(fee_detail_id: fee_detail1.id)
      end.to change(WorkOrderFeeDetail, :count).by(-1)
    end
  end

  describe '.safe_find' do
    it 'finds association safely' do
      result = described_class.safe_find(association1.id)
      expect(result).to eq(association1)
    end

    it 'returns nil on not found' do
      result = described_class.safe_find(99999)
      expect(result).to be_nil
    end

    it 'handles exceptions gracefully' do
      allow(WorkOrderFeeDetail).to receive(:find_by).and_raise(StandardError.new('Database error'))
      result = described_class.safe_find(association1.id)
      expect(result).to be_nil
    end
  end

  describe '.safe_find_by_id' do
    it 'finds association safely' do
      result = described_class.safe_find_by_id(association1.id)
      expect(result).to eq(association1)
    end

    it 'returns nil on not found' do
      result = described_class.safe_find_by_id(99999)
      expect(result).to be_nil
    end

    it 'handles exceptions gracefully' do
      allow(WorkOrderFeeDetail).to receive(:find_by).and_raise(StandardError.new('Database error'))
      result = described_class.safe_find_by_id(association1.id)
      expect(result).to be_nil
    end
  end
end
