require 'rails_helper'

RSpec.describe FeeDetailImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:file_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_fee_details.xlsx') }
  let(:file) { fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

  before do
    FileUtils.mkdir_p(Rails.root.join('spec', 'fixtures', 'files'))

    unless File.exist?(file_path)
      workbook = WriteXLSX.new(file_path)
      worksheet = workbook.add_worksheet

      headers = ['费用明细编号', '报销单单号', '费用描述', '金额', '状态']
      headers.each_with_index do |header, index|
        worksheet.write(0, index, header)
      end

      data = [
        ['FD20250101001', 'R20250101001', '交通费用', 300, '已审核'],
        ['FD20250101002', 'R20250101002', '餐费', 500, '待审核'],
        ['FD20250101003', 'R20250101003', '住宿费用', 1000, '拒绝']
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
    context '当文件不存在时' do
      it '返回错误信息' do
        service = FeeDetailImportService.new(nil, admin_user)
        result = service.import

        expect(result[:success]).to be_falsey
        expect(result[:errors]).to include('文件不存在')
      end
    end

    context '当文件格式不支持时' do
      let(:invalid_file) { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'invalid_file.txt'), 'text/plain') }

      it '返回错误信息' do
        service = FeeDetailImportService.new(invalid_file, admin_user)
        expect { service.import }.to raise_error(/未知的文件类型/)
      end
    end

    context '当文件有效时' do
      it '导入费用明细数据' do
        create(:audit_work_order, invoice_number: 'R20250101001')
        create(:audit_work_order, invoice_number: 'R20250101002')
        create(:audit_work_order, invoice_number: 'R20250101003')

        service = FeeDetailImportService.new(file, admin_user)

        expect {
          result = service.import
          expect(result[:success]).to be_truthy
          expect(result[:created]).to eq(3)
          expect(result[:updated]).to eq(0)
          expect(result[:errors]).to eq(0)
        }.to change(FeeDetail, :count).by(3)
      end

      it '更新已存在的费用明细' do
        create(:audit_work_order, invoice_number: 'R20250101001')
        create(:fee_detail, detail_number: 'FD20250101001', amount: 200)

        service = FeeDetailImportService.new(file, admin_user)

        expect {
          result = service.import
          expect(result[:success]).to be_truthy
          expect(result[:created]).to eq(2)
          expect(result[:updated]).to eq(1)
        }.to change(FeeDetail, :count).by(2)

        fee_detail = FeeDetail.find_by(detail_number: 'FD20250101001')
        expect(fee_detail.amount).to eq(300)
      end

      it '处理缺少必要字段的行' do
        invalid_file_path = Rails.root.join('spec', 'fixtures', 'files', 'invalid_fee_details.xlsx')
        workbook = WriteXLSX.new(invalid_file_path)
        worksheet = workbook.add_worksheet

        headers = ['费用明细编号', '报销单单号', '费用描述', '金额', '状态']
        headers.each_with_index do |header, index|
          worksheet.write(0, index, header)
        end

        worksheet.write(1, 0, nil)
        worksheet.write(1, 1, 'R20250101004')
        worksheet.write(1, 2, '其他费用')
        worksheet.write(1, 3, 400)
        worksheet.write(1, 4, '已审核')

        workbook.close

        invalid_file = fixture_file_upload(invalid_file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        service = FeeDetailImportService.new(invalid_file, admin_user)

        result = service.import
        expect(result[:success]).to be_truthy
        expect(result[:created]).to eq(0)
        expect(result[:updated]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details]).to include(/行 2: 费用明细编号不能为空/)
      end
    end
  end
end