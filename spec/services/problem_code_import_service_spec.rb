require 'rails_helper'

RSpec.describe ProblemCodeImportService, type: :service do
  let(:csv_content) do
    <<~CSV
      reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
      EN,00,个人,01,月度交通费,01,"燃油费行程问题","根据SOP规定...","请根据要求...",EN000101
      EN,00,个人,02,市内交通费,02,"出租车行程问题","根据SOP规定...","请根据要求...",EN000102
      MN,01,学术论坛,01,会议讲课费,01,"非讲者库讲者","根据SOP规定...","不符合要求...",MN010101
      MN,01,学术论坛,00,通用,01,"会议权限问题","根据SOP规定...","请提供...",MN010001
    CSV
  end

  let(:csv_file_path) do
    file = Tempfile.new(['test_problem_codes', '.csv'])
    file.write(csv_content)
    file.close
    file.path
  end

  after do
    FileUtils.rm(csv_file_path)
  end

  subject(:service) { described_class.new(csv_file_path) }

  describe '#import' do
    context 'when importing new records' do
      it 'creates the correct number of FeeType records' do
        expect { service.import }.to change(FeeType, :count).by(4)
        # EN-00-01, EN-00-02, MN-01-01, MN-01-00
      end

      it 'creates FeeType records with correct attributes' do
        service.import
        fee_type = FeeType.find_by(reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01')
        expect(fee_type.name).to eq('月度交通费')
        expect(fee_type.meeting_name).to eq('个人')
      end
      
      it 'creates the correct number of ProblemType records' do
        expect { service.import }.to change(ProblemType, :count).by(4)
        # EN-00-01-01, EN-00-02-02, MN-01-01-01, MN-01-00-01
      end

      it 'creates ProblemType records with correct attributes' do
        service.import
        problem_type = ProblemType.find_by(legacy_problem_code: 'EN000101')
        expect(problem_type.reimbursement_type_code).to eq('EN')
        expect(problem_type.meeting_type_code).to eq('00')
        expect(problem_type.expense_type_code).to eq('01')
        expect(problem_type.code).to eq('01') # issue_code
        expect(problem_type.title).to eq('燃油费行程问题')
      end
    end

    context 'when updating existing records' do
      before do
        # Pre-seed the database with one record
        described_class.new(csv_file_path).import
      end

      let(:updated_csv_content) do
        <<~CSV
          reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
          EN,00,个人,01,月度交通费,01,"燃油费行程问题 Updated","根据SOP规定... Updated","请根据要求... Updated",EN000101
          MN,02,患者教育,01,会议餐费,01,"新问题","新SOP","新方法",MN020101
        CSV
      end

      let(:updated_csv_file_path) do
        file = Tempfile.new(['updated_codes', '.csv'])
        file.write(updated_csv_content)
        file.close
        file.path
      end

      subject(:updated_service) { described_class.new(updated_csv_file_path) }

      it 'does not create new records for existing codes' do
        expect { updated_service.import }.to change(ProblemType, :count).by(1) # Only MN020101 is new
      end
      
      it 'updates the attributes of existing records' do
        updated_service.import
        problem_type = ProblemType.find_by(legacy_problem_code: 'EN000101')
        expect(problem_type.title).to eq('燃油费行程问题 Updated')
        expect(problem_type.sop_description).to eq('根据SOP规定... Updated')
      end
    end

    context 'with invalid data' do
      let(:invalid_csv_content) do
        <<~CSV
          reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
          EN,00,个人,01,月度交通费,01,"","",,EN000101
        CSV
      end
      
      let(:invalid_csv_file_path) do
        file = Tempfile.new(['invalid_codes', '.csv'])
        file.write(invalid_csv_content)
        file.close
        file.path
      end
      
      subject(:invalid_service) { described_class.new(invalid_csv_file_path) }
      
      it 'skips rows with missing essential data' do
        expect { invalid_service.import }.not_to change(ProblemType, :count)
      end
    end
  end
end