require 'rails_helper'

RSpec.describe ExpressReceiptImportService, type: :service do
  let(:valid_file_path) { Rails.root.join('spec', 'fixtures', 'files', 'valid_express_receipts.xlsx') }
  let(:invalid_file_path) { Rails.root.join('spec', 'fixtures', 'files', 'invalid_express_receipts.xlsx') }
  let(:admin_user) { create(:admin_user) }
  let(:service) { ExpressReceiptImportService.new(valid_file_path, admin_user) }

  describe '#import' do
    context '当文件不存在时' do
      it '返回错误信息' do
        expect { ExpressReceiptImportService.new('non_existent_file.xlsx', admin_user).import }.to raise_error(/文件不存在/)
      end
    end

    context '当文件格式不支持时' do
      it '返回错误信息' do
        expect { ExpressReceiptImportService.new('unsupported_format.txt', admin_user).import }.to raise_error(/未知的文件类型/)
      end
    end

    context '当文件有效时' do
      it '导入快递收单数据' do
        expect {
          result = service.import
          expect(result[:success]).to be_truthy
          expect(result[:matched]).to eq(7)
          expect(result[:unmatched]).to eq(0)
          expect(result[:errors]).to eq(0)
        }.to change(ExpressReceipt, :count).by(7)
      end

      it '为未匹配的快递单记录错误信息' do
        service = ExpressReceiptImportService.new(invalid_file_path, admin_user)
        result = service.import
        expect(result[:success]).to be_falsey
        expect(result[:errors]).to eq(1)
      end

      it '创建快递收单工单' do
        expect {
          service.import
        }.to change(ExpressReceiptWorkOrder, :count).by(7)
      end
    end
  end

  describe '#manual_match' do
    it '手动匹配未匹配的快递单' do
      unmatched_data = service.send(:manual_match)
      expect(unmatched_data[:error]).to eq('报销单不存在')
    end
  end
end