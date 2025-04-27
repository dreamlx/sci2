require 'rails_helper'

RSpec.describe OperationHistoryImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:file_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_operation_histories.xlsx') }
  let(:file) { fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

  before do
    FileUtils.mkdir_p(Rails.root.join('spec', 'fixtures', 'files'))

    unless File.exist?(file_path)
      workbook = WriteXLSX.new(file_path)
      worksheet = workbook.add_worksheet

      headers = ['操作历史编号', '工单编号', '操作类型', '操作时间', '操作人', '备注']
      headers.each_with_index do |header, index|
        worksheet.write(0, index, header)
      end

      data = [
        ['OH20250101001', 'WO20250101001', '提交', '2025-01-01 10:00:00', '张三', '无'],
        ['OH20250101002', 'WO20250101002', '审核', '2025-01-02 11:00:00', '李四', '已通过'],
        ['OH20250101003', 'WO20250101003', '沟通', '2025-01-03 12:00:00', '王五', '需要进一步沟通'],
        ['OH20250101004', 'WO20250101004', '完成', '2025-01-04 13:00:00', '赵六', '无']
      ]

      data.each_with_index do |row, row_index|
        row.each_with_index do |value, col_index|
          worksheet.write(row_index + 1, col_index, value)
        end
      end

      workbook.close
    end
  end

  describe '#import' do
    context 'when file is missing' do
      it 'returns an error message' do
        service = OperationHistoryImportService.new(nil, admin_user)
        result = service.import

        expect(result[:success]).to be_falsey
        expect(result[:errors]).to include('文件不存在')
      end
    end

    context 'when file format is unsupported' do
      let(:invalid_file) { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'invalid_file.txt'), 'text/plain') }

      it 'returns an error message' do
        service = OperationHistoryImportService.new(invalid_file, admin_user)
        expect { service.import }.to raise_error(/未知的文件类型/)
      end
    end

    context 'when file is valid' do
      it 'imports operation history data' do
        create(:work_order, order_number: 'WO20250101001')
        create(:work_order, order_number: 'WO20250101002')
        create(:work_order, order_number: 'WO20250101003')
        create(:work_order, order_number: 'WO20250101004')

        service = OperationHistoryImportService.new(file, admin_user)

        expect {
          result = service.import
          expect(result[:success]).to be_truthy
          expect(result[:created]).to eq(4)
          expect(result[:updated]).to eq(0)
          expect(result[:errors]).to eq(0)
        }.to change(OperationHistory, :count).by(4)
      end

      it 'updates existing operation history records' do
        create(:work_order, order_number: 'WO20250101001')
        create(:operation_history, history_number: 'OH20250101001', remarks: '旧备注')

        service = OperationHistoryImportService.new(file, admin_user)

        expect {
          result = service.import
          expect(result[:success]).to be_truthy
          expect(result[:created]).to eq(3)
          expect(result[:updated]).to eq(1)
        }.to change(OperationHistory, :count).by(3)

        history = OperationHistory.find_by(history_number: 'OH20250101001')
        expect(history.remarks).to eq('无')
      end

      it 'handles missing required fields' do
        invalid_file_path = Rails.root.join('spec', 'fixtures', 'files', 'invalid_operation_histories.xlsx')
        workbook = WriteXLSX.new(invalid_file_path)
        worksheet = workbook.add_worksheet

        headers = ['操作历史编号', '工单编号', '操作类型', '操作时间', '操作人', '备注']
        headers.each_with_index do |header, index|
          worksheet.write(0, index, header)
        end

        worksheet.write(1, 0, nil)
        worksheet.write(1, 1, 'WO20250101005')
        worksheet.write(1, 2, '提交')
        worksheet.write(1, 3, '2025-01-05 10:00:00')
        worksheet.write(1, 4, '未知提交人')
        worksheet.write(1, 5, '无')

        workbook.close

        invalid_file = fixture_file_upload(invalid_file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        service = OperationHistoryImportService.new(invalid_file, admin_user)

        result = service.import
        expect(result[:success]).to be_truthy
        expect(result[:created]).to eq(0)
        expect(result[:updated]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details]).to include(/行 2: 操作历史编号不能为空/)
      end
    end
  end
end