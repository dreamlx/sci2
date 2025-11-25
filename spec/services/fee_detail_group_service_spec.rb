require 'rails_helper'

RSpec.describe FeeDetailGroupService, type: :service do
  let(:fee_type1) do
    FeeType.create!(
      code: '00',
      title: '月度交通费（销售/SMO/CO）',
      meeting_type: '个人',
      active: true
    )
  end

  let(:fee_type2) do
    FeeType.create!(
      code: '01',
      title: '办公费',
      meeting_type: '个人',
      active: true
    )
  end

  let(:problem_type1) do
    ProblemType.create!(
      code: '01',
      title: '燃油费行程问题',
      sop_description: '检查燃油费是否与行程匹配',
      standard_handling: '要求提供详细行程单',
      fee_type: fee_type1,
      active: true
    )
  end

  let(:problem_type2) do
    ProblemType.create!(
      code: '02',
      title: '交通费超标',
      sop_description: '检查交通费是否超过标准',
      standard_handling: '要求提供说明',
      fee_type: fee_type1,
      active: true
    )
  end

  let(:problem_type3) do
    ProblemType.create!(
      code: '01',
      title: '办公用品超标',
      sop_description: '检查办公用品是否超过标准',
      standard_handling: '要求提供说明',
      fee_type: fee_type2,
      active: true
    )
  end

  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: 'INV-001',
      document_name: '个人报销单',
      status: 'processing',
      is_electronic: true
    )
  end

  let!(:fee_detail1) do
    FeeDetail.create!(
      document_number: reimbursement.invoice_number,
      external_fee_id: 'FEE001',
      fee_type: '月度交通费（销售/SMO/CO）',
      amount: 100.0,
      fee_date: Date.today,
      verification_status: 'pending'
    )
  end

  let!(:fee_detail2) do
    FeeDetail.create!(
      document_number: reimbursement.invoice_number,
      external_fee_id: 'FEE002',
      fee_type: '月度交通费（销售/SMO/CO）',
      amount: 200.0,
      fee_date: Date.today,
      verification_status: 'pending'
    )
  end

  let!(:fee_detail3) do
    FeeDetail.create!(
      document_number: reimbursement.invoice_number,
      external_fee_id: 'FEE003',
      fee_type: '办公费',
      amount: 300.0,
      fee_date: Date.today,
      verification_status: 'pending'
    )
  end

  describe '#group_by_fee_type' do
    it 'groups fee details by fee type' do
      service = FeeDetailGroupService.new([fee_detail1.id, fee_detail2.id, fee_detail3.id])
      groups = service.group_by_fee_type

      expect(groups.size).to eq(2)

      # 找到月度交通费组
      transport_group = groups.find { |g| g[:fee_type] == '月度交通费（销售/SMO/CO）' }
      expect(transport_group).not_to be_nil
      expect(transport_group[:details].size).to eq(2)
      expect(transport_group[:details].map { |d| d[:id] }).to include(fee_detail1.id, fee_detail2.id)

      # 找到办公费组
      office_group = groups.find { |g| g[:fee_type] == '办公费' }
      expect(office_group).not_to be_nil
      expect(office_group[:details].size).to eq(1)
      expect(office_group[:details].first[:id]).to eq(fee_detail3.id)
    end

    it 'returns empty array if no fee details are provided' do
      service = FeeDetailGroupService.new([])
      groups = service.group_by_fee_type

      expect(groups).to be_empty
    end
  end

  describe '#fee_types' do
    it 'returns unique fee types' do
      service = FeeDetailGroupService.new([fee_detail1.id, fee_detail2.id, fee_detail3.id])
      fee_types = service.fee_types

      expect(fee_types.size).to eq(2)
      expect(fee_types).to include('月度交通费（销售/SMO/CO）', '办公费')
    end
  end

  describe '#fee_type_ids' do
    it 'returns fee type ids' do
      service = FeeDetailGroupService.new([fee_detail1.id, fee_detail2.id, fee_detail3.id])
      fee_type_ids = service.fee_type_ids

      expect(fee_type_ids.size).to eq(2)
      expect(fee_type_ids).to include(fee_type1.id, fee_type2.id)
    end
  end

  describe '#available_problem_types' do
    it 'returns problem types for the fee types' do
      service = FeeDetailGroupService.new([fee_detail1.id, fee_detail2.id, fee_detail3.id])
      problem_types = service.available_problem_types

      expect(problem_types.size).to eq(3)
      expect(problem_types).to include(problem_type1, problem_type2, problem_type3)
    end
  end

  describe '#problem_types_by_fee_type' do
    it 'groups problem types by fee type' do
      service = FeeDetailGroupService.new([fee_detail1.id, fee_detail2.id, fee_detail3.id])
      grouped = service.problem_types_by_fee_type

      expect(grouped.size).to eq(2)

      # 检查月度交通费的问题类型
      expect(grouped[fee_type1.id].size).to eq(2)
      expect(grouped[fee_type1.id].map { |pt| pt[:id] }).to include(problem_type1.id, problem_type2.id)

      # 检查办公费的问题类型
      expect(grouped[fee_type2.id].size).to eq(1)
      expect(grouped[fee_type2.id].first[:id]).to eq(problem_type3.id)
    end
  end
end
