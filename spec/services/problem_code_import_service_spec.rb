require 'rails_helper'

RSpec.describe ProblemCodeImportService, type: :service do
  let!(:csv_file_path) { Tempfile.new(['test_problem_codes', '.csv']).path }

  after do
    FileUtils.rm(csv_file_path) if File.exist?(csv_file_path)
  end

  def create_csv(content)
    File.write(csv_file_path, content)
  end

  subject(:service) { described_class.new(csv_file_path) }

  describe '#import' do
    context 'when importing new records' do
      let(:csv_content) do
        <<~CSV
          reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
          EN,00,个人,01,月度交通费,01,"燃油费行程问题","根据SOP规定...","请根据要求...",EN000101
          EN,00,个人,02,市内交通费,02,"出租车行程问题","根据SOP规定...","请根据要求...",EN000102
          MN,01,学术论坛,01,会议讲课费,01,"非讲者库讲者","根据SOP规定...","不符合要求...",MN010101
          MN,01,学术论坛,00,通用,01,"会议权限问题","根据SOP规定...","请提供...",MN010001
        CSV
      end

      before { create_csv(csv_content) }

      it 'creates the correct number of FeeType records' do
        expect { service.import }.to change(FeeType, :count).by(4)
      end

      it 'creates FeeType records with correct attributes' do
        service.import
        fee_type = FeeType.find_by(reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01')
        expect(fee_type.name).to eq('月度交通费')
        expect(fee_type.meeting_name).to eq('个人')
      end

      it 'creates the correct number of ProblemType records' do
        expect { service.import }.to change(ProblemType, :count).by(4)
      end

      it 'creates ProblemType records with correct attributes' do
        service.import
        fee_type = FeeType.find_by(reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01')
        problem_type = ProblemType.find_by(fee_type: fee_type, issue_code: '01')

        expect(problem_type).not_to be_nil
        expect(problem_type.title).to eq('燃油费行程问题')
        expect(problem_type.legacy_problem_code).to eq('EN000101')
      end
    end

    context 'when updating existing records' do
      before do
        initial_csv = <<~CSV
          reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
          EN,00,个人,01,月度交通费,01,"燃油费行程问题","根据SOP规定...","请根据要求...",EN000101
        CSV
        create_csv(initial_csv)
        described_class.new(csv_file_path).import

        updated_csv = <<~CSV
          reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
          EN,00,个人,01,月度交通费,01,"燃油费行程问题 Updated","根据SOP规定... Updated","请根据要求... Updated",EN000101
          MN,02,患者教育,01,会议餐费,01,"新问题","新SOP","新方法",MN020101
        CSV
        create_csv(updated_csv)
      end

      it 'does not create new records for existing codes' do
        expect { service.import }.to change(ProblemType, :count).by(1) # Only MN020101 is new
      end

      it 'updates the attributes of existing records' do
        service.import
        fee_type = FeeType.find_by(reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01')
        problem_type = ProblemType.find_by(fee_type: fee_type, issue_code: '01')

        expect(problem_type.title).to eq('燃油费行程问题 Updated')
        expect(problem_type.sop_description).to eq('根据SOP规定... Updated')
      end
    end

    context 'with invalid data' do
      before do
        invalid_csv = <<~CSV
          reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
          EN,00,个人,01,月度交通费,01,"","",,EN000101
        CSV
        create_csv(invalid_csv)
      end

      it 'skips rows with missing essential data' do
        expect { service.import }.not_to change(ProblemType, :count)
      end
    end
  end
end
