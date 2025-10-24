require 'rails_helper'

RSpec.describe ProblemFinderService, type: :service do
  describe '.find_for' do
    let!(:reimbursement_en) { create(:reimbursement, document_name: '个人日常报销单') }
    let!(:reimbursement_mn) { create(:reimbursement, document_name: '学术会议报销单') }

    let!(:fee_detail_en) { create(:fee_detail, reimbursement: reimbursement_en, fee_type: '月度交通费', flex_field_7: '00') }
    let!(:fee_detail_mn) { create(:fee_detail, reimbursement: reimbursement_mn, fee_type: '会议讲课费', flex_field_7: '01') }

    # Setup FeeTypes Dictionary
    let!(:fee_type_en_precise) do
      create(:fee_type, reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01', name: '月度交通费')
    end
    let!(:fee_type_mn_precise) do
      create(:fee_type, reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '01', name: '会议讲课费')
    end
    let!(:fee_type_mn_general) do
      create(:fee_type, reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '00', name: '通用')
    end

    # Setup ProblemTypes
    let!(:problem_en_precise) do
      create(:problem_type, reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01',
                            title: 'EN precise problem')
    end
    let!(:problem_en_general) do
      create(:problem_type, reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '00',
                            title: 'EN general problem')
    end
    let!(:problem_mn_precise) do
      create(:problem_type, reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '01',
                            title: 'MN precise problem')
    end
    let!(:problem_mn_general) do
      create(:problem_type, reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '00',
                            title: 'MN general problem')
    end
    let!(:unrelated_problem) do
      create(:problem_type, reimbursement_type_code: 'MN', meeting_type_code: '99', expense_type_code: '99',
                            title: 'Unrelated problem')
    end

    context 'when there is a precise match and a general match' do
      it 'returns both precise and general problems' do
        results = described_class.find_for(reimbursement_mn, fee_detail_mn)
        expect(results).to contain_exactly(problem_mn_precise, problem_mn_general)
      end
    end

    context 'when there is only a general match (user entered fee_type does not match)' do
      let!(:fee_detail_en_unmatched) do
        create(:fee_detail, reimbursement: reimbursement_en, fee_type: '不存在的费用类型', flex_field_7: '00')
      end

      it 'returns only the general problems' do
        results = described_class.find_for(reimbursement_en, fee_detail_en_unmatched)
        expect(results).to contain_exactly(problem_en_general)
      end
    end

    context 'when user entered fee_type matches but there are no precise problems, only general' do
      let!(:fee_type_en_no_precise_problems) do
        create(:fee_type, reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '02', name: '市内交通')
      end
      let!(:fee_detail_en_no_precise_problems) do
        create(:fee_detail, reimbursement: reimbursement_en, fee_type: '市内交通', flex_field_7: '00')
      end

      it 'returns only the general problems' do
        results = described_class.find_for(reimbursement_en, fee_detail_en_no_precise_problems)
        expect(results).to contain_exactly(problem_en_general)
      end
    end

    context 'when context does not match anything' do
      let!(:unmatched_reimbursement) { create(:reimbursement, document_name: '其他报销单') }
      let!(:unmatched_fee_detail) { create(:fee_detail, reimbursement: unmatched_reimbursement, flex_field_7: '99') }

      it 'returns an empty collection' do
        results = described_class.find_for(unmatched_reimbursement, unmatched_fee_detail)
        expect(results).to be_empty
      end
    end
  end
end
