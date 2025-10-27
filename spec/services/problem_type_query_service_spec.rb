# spec/services/problem_type_query_service_spec.rb
require 'rails_helper'

RSpec.describe ProblemTypeQueryService do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail_ids) { [] }
  let(:service) { described_class.new(fee_detail_ids: fee_detail_ids, reimbursement: reimbursement) }

  describe '#call' do
    context 'when no fee detail IDs provided' do
      it 'returns empty array' do
        result = service.call
        expect(result).to eq([])
      end
    end

    context 'when fee detail IDs do not exist' do
      let(:fee_detail_ids) { [999, 1000] }

      it 'returns empty array' do
        result = service.call
        expect(result).to eq([])
      end
    end

    context 'with valid fee details' do
      let(:fee_detail1) { create(:fee_detail, fee_type: '交通费', flex_field_7: '国内会议') }
      let(:fee_detail2) { create(:fee_detail, fee_type: '住宿费', flex_field_7: '国际会议') }
      let(:fee_detail_ids) { [fee_detail1.id, fee_detail2.id] }

      before do
        # Create meeting name mappings
        create(:fee_type, meeting_name: '国内会议', meeting_type_code: '01')
        create(:fee_type, meeting_name: '国际会议', meeting_type_code: '02')
      end

      context 'with personal reimbursement document' do
        let(:reimbursement) { create(:reimbursement, document_name: '个人日常报销单') }

        it 'returns array of problem types' do
          result = service.call
          expect(result).to be_an(Array)
        end
      end

      context 'with academic conference reimbursement document' do
        let(:reimbursement) { create(:reimbursement, document_name: '学术会议报销单') }

        it 'returns array of problem types' do
          result = service.call
          expect(result).to be_an(Array)
        end
      end

      context 'with travel reimbursement document' do
        let(:reimbursement) { create(:reimbursement, document_name: '差旅报销单') }

        it 'returns array of problem types' do
          result = service.call
          expect(result).to be_an(Array)
        end
      end
    end

    context 'edge cases' do
      let(:fee_detail) { create(:fee_detail, fee_type: '测试费', flex_field_7: nil) }
      let(:fee_detail_ids) { [fee_detail.id] }
      let(:reimbursement) { create(:reimbursement, document_name: '个人日常报销单') }

      it 'handles fee details with blank meeting name' do
        result = service.call
        expect(result).to eq([])
      end

      context 'with fee detail having meeting name but no matching fee type' do
        let(:fee_detail) { create(:fee_detail, fee_type: '测试费', flex_field_7: '未知会议') }
        let(:fee_detail_ids) { [fee_detail.id] }

        it 'handles missing meeting type code gracefully' do
          result = service.call
          expect(result).to eq([])
        end
      end
    end
  end

  describe 'private methods' do
    let(:service) { described_class.new(fee_detail_ids: [], reimbursement: reimbursement) }

    describe '#determine_reimbursement_type' do
      context 'with personal daily reimbursement' do
        let(:reimbursement) { create(:reimbursement, document_name: '个人日常报销单') }

        it 'returns EN' do
          result = service.send(:determine_reimbursement_type)
          expect(result).to eq('EN')
        end
      end

      context 'with travel reimbursement' do
        let(:reimbursement) { create(:reimbursement, document_name: '差旅报销单') }

        it 'returns EN' do
          result = service.send(:determine_reimbursement_type)
          expect(result).to eq('EN')
        end
      end

      context 'with academic conference reimbursement' do
        let(:reimbursement) { create(:reimbursement, document_name: '学术会议报销单') }

        it 'returns MN' do
          result = service.send(:determine_reimbursement_type)
          expect(result).to eq('MN')
        end
      end

      context 'with unknown document type' do
        let(:reimbursement) { create(:reimbursement, document_name: '未知报销类型') }

        it 'defaults to EN' do
          result = service.send(:determine_reimbursement_type)
          expect(result).to eq('EN')
        end
      end
    end
  end

  describe 'basic functionality' do
    it 'initializes with required parameters' do
      expect { described_class.new(fee_detail_ids: [1], reimbursement: reimbursement) }.not_to raise_error
    end

    it 'responds to call method' do
      expect(service).to respond_to(:call)
    end
  end
end