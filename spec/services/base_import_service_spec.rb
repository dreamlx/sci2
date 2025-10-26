# spec/services/base_import_service_spec.rb
require 'rails_helper'

RSpec.describe BaseImportService, type: :service do
  let(:file) { double('file') }
  let(:admin_user) { create(:admin_user) }
  let(:service) { described_class.new(file, admin_user) }

  describe '#initialize' do
    it 'initializes with required attributes' do
      expect(service.file).to eq(file)
      expect(service.current_admin_user).to eq(admin_user)
      expect(service.created_count).to eq(0)
      expect(service.skipped_count).to eq(0)
      expect(service.error_count).to eq(0)
      expect(service.errors).to eq([])
    end

    it 'sets Current.admin_user' do
      expect(Current.admin_user).to eq(admin_user)
    end
  end

  describe '#import' do
    it 'raises NotImplementedError' do
      expect { service.import }.to raise_error(NotImplementedError, "子类必须实现 import 方法")
    end
  end

  describe '#validate_file' do
    context 'with valid file and user' do
      let(:file) { double('file', present?: true) }
      let(:admin_user) { double('admin_user') }

      it 'returns success' do
        result = service.send(:validate_file)
        expect(result[:success]).to be true
      end
    end

    context 'with missing file' do
      let(:file) { double('file', present?: false) }
      let(:admin_user) { double('admin_user') }

      it 'returns error for missing file' do
        result = service.send(:validate_file)
        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end
    end

    context 'with missing user' do
      let(:file) { double('file', present?: true) }
      let(:admin_user) { nil }

      it 'returns error for missing user' do
        result = service.send(:validate_file)
        expect(result[:success]).to be false
        expect(result[:errors]).to include('导入用户不存在')
      end
    end
  end

  describe '#parse_file' do
    let(:file) { double('file', present?: true) }
    let(:admin_user) { double('admin_user') }
    let(:test_spreadsheet) { nil }

    context 'with valid file' do
      before do
        allow(service).to receive(:extract_file_path).and_return('/tmp/test.csv')
        allow(service).to receive(:extract_file_extension).and_return('csv')
        allow(service).to receive(:supported_extension?).with('csv').and_return(true)

        mock_spreadsheet = double('spreadsheet')
        mock_sheet = double('sheet')
        allow(Roo::Spreadsheet).to receive(:open).and_return(mock_spreadsheet)
        allow(service).to receive(:extract_sheet).with(mock_spreadsheet).and_return(mock_sheet)
        allow(service).to receive(:extract_headers).with(mock_sheet).and_return(['header1', 'header2'])
      end

      it 'returns success with parsed data' do
        result = service.send(:parse_file, test_spreadsheet)
        expect(result[:success]).to be true
        expect(result[:sheet]).to be_present
        expect(result[:headers]).to eq(['header1', 'header2'])
      end
    end

    context 'with invalid file extension' do
      before do
        allow(service).to receive(:extract_file_path).and_return('/tmp/test.txt')
        allow(service).to receive(:extract_file_extension).and_return('txt')
      end

      it 'returns error for unsupported format' do
        result = service.send(:parse_file, test_spreadsheet)
        expect(result[:success]).to be false
        expect(result[:errors]).to include('不支持的文件格式，请上传 CSV 或 Excel 文件')
      end
    end

    context 'with parsing error' do
      before do
        allow(service).to receive(:extract_file_path).and_return('/tmp/test.csv')
        allow(service).to receive(:extract_file_extension).and_return('csv')
        allow(service).to receive(:supported_extension?).with('csv').and_return(true)
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError, 'Parse error')
      end

      it 'handles parsing errors gracefully' do
        result = service.send(:parse_file, test_spreadsheet)
        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件解析失败: Parse error')
      end
    end
  end

  describe '#process_rows' do
    let(:mock_sheet) { double('sheet') }
    let(:headers) { ['header1', 'header2'] }

    before do
      allow(Rails.logger).to receive(:info)
    end

    it 'processes each row with header mapping' do
      row1 = ['value1', 'value2']
      row2 = ['value3', 'value4']

      allow(mock_sheet).to receive(:each_with_index).and_yield(['header1', 'header2'], 0)
                                                      .and_yield(row1, 1)
                                                      .and_yield(row2, 2)

      processed_data = []

      service.send(:process_rows, mock_sheet, headers) do |row_data, row_number|
        processed_data << { data: row_data, number: row_number }
      end

      expect(processed_data.length).to eq(2)
      expect(processed_data[0]).to eq({ data: { 'header1' => 'value1', 'header2' => 'value2' }, number: 2 })
      expect(processed_data[1]).to eq({ data: { 'header1' => 'value3', 'header2' => 'value4' }, number: 3 })
    end

    it 'skips header row' do
      allow(mock_sheet).to receive(:each_with_index).and_yield(['header1', 'header2'], 0)

      processed_data = []

      service.send(:process_rows, mock_sheet, headers) do |row_data, row_number|
        processed_data << row_number
      end

      expect(processed_data).to be_empty
    end
  end

  describe '#handle_error' do
    before do
      allow(Rails.logger).to receive(:error)
    end

    it 'increments error count and adds to errors array' do
      error = StandardError.new('Test error')

      service.send(:handle_error, error, message: 'Context message')

      expect(service.error_count).to eq(1)
      expect(service.errors).to include('Context message: Test error')
    end

    it 'logs error message' do
      error = StandardError.new('Test error')

      expect(Rails.logger).to receive(:error).with('Context message: Test error')

      service.send(:handle_error, error, message: 'Context message')
    end

    context 'when reraise is true' do
      it 're-raises the error' do
        error = StandardError.new('Test error')

        expect { service.send(:handle_error, error, message: 'Context', reraise: true) }
          .to raise_error(StandardError, 'Test error')
      end
    end

    context 'when reraise is false' do
      it 'does not re-raise the error' do
        error = StandardError.new('Test error')

        expect { service.send(:handle_error, error, message: 'Context', reraise: false) }
          .not_to raise_error
      end
    end
  end

  describe '#format_result' do
    before do
      service.instance_variable_set(:@created_count, 5)
      service.instance_variable_set(:@error_count, 2)
      service.instance_variable_set(:@skipped_count, 1)
      service.instance_variable_set(:@errors, ['Error 1', 'Error 2'])
    end

    it 'returns formatted result with default values' do
      result = service.send(:format_result)

      expect(result[:success]).to be false # because error_count > 0
      expect(result[:created]).to eq(5)
      expect(result[:updated]).to eq(0)
      expect(result[:errors]).to eq(2)
      expect(result[:error_details]).to eq(['Error 1', 'Error 2'])
      expect(result[:skipped]).to eq(1)
    end

    it 'merges additional data' do
      additional_data = { custom_field: 'custom_value' }

      result = service.send(:format_result, additional_data)

      expect(result[:custom_field]).to eq('custom_value')
    end

    context 'when no errors' do
      before do
        service.instance_variable_set(:@error_count, 0)
      end

      it 'returns success: true' do
        result = service.send(:format_result)
        expect(result[:success]).to be true
      end
    end
  end

  describe 'private helper methods' do
    describe '#extract_file_path' do
      context 'with tempfile' do
        let(:tempfile) { double('tempfile', to_path: double('path', to_s: '/tmp/tempfile')) }
        let(:file) { double('file', tempfile: tempfile) }

        before do
          allow(service).to receive(:file).and_return(file)
        end

        it 'extracts path from tempfile' do
          path = service.send(:extract_file_path)
          expect(path).to eq('/tmp/tempfile')
        end
      end

      context 'with regular file' do
        let(:file) { double('file', tempfile: nil, path: '/tmp/regular_file') }

        before do
          allow(service).to receive(:file).and_return(file)
        end

        it 'extracts path from file' do
          path = service.send(:extract_file_path)
          expect(path).to eq('/tmp/regular_file')
        end
      end
    end

    describe '#extract_file_extension' do
      it 'extracts extension without dot' do
        path = service.send(:extract_file_extension, '/tmp/test.csv')
        expect(path).to eq('csv')
      end

      it 'handles uppercase extensions' do
        path = service.send(:extract_file_extension, '/tmp/test.XLSX')
        expect(path).to eq('xlsx')
      end
    end

    describe '#supported_extension?' do
      it 'returns true for supported extensions' do
        expect(service.send(:supported_extension?, 'csv')).to be true
        expect(service.send(:supported_extension?, 'xls')).to be true
        expect(service.send(:supported_extension?, 'xlsx')).to be true
      end

      it 'returns false for unsupported extensions' do
        expect(service.send(:supported_extension?, 'txt')).to be false
        expect(service.send(:supported_extension?, 'pdf')).to be false
      end
    end

    describe '#extract_sheet' do
      context 'with spreadsheet that has sheet method' do
        let(:spreadsheet) { double('spreadsheet') }
        let(:sheet) { double('sheet') }

        before do
          allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(true)
          allow(spreadsheet).to receive(:sheet).with(0).and_return(sheet)
        end

        it 'extracts first sheet' do
          result = service.send(:extract_sheet, spreadsheet)
          expect(result).to eq(sheet)
        end
      end

      context 'with spreadsheet that does not have sheet method' do
        let(:spreadsheet) { double('spreadsheet') }

        before do
          allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        end

        it 'returns spreadsheet directly' do
          result = service.send(:extract_sheet, spreadsheet)
          expect(result).to eq(spreadsheet)
        end
      end
    end

    describe '#extract_headers' do
      let(:sheet) { double('sheet') }

      before do
        allow(sheet).to receive(:row).with(1).and_return(['Header 1', '  Header 2  ', ''])
      end

      it 'extracts and strips headers' do
        headers = service.send(:extract_headers, sheet)
        expect(headers).to eq(['Header 1', 'Header 2', ''])
      end
    end
  end

  describe 'subclass methods' do
    describe '#validate_row_data' do
      it 'returns true by default' do
        result = service.send(:validate_row_data, {}, 1)
        expect(result).to be true
      end
    end

    describe '#process_valid_row' do
      it 'raises NotImplementedError' do
        expect { service.send(:process_valid_row, {}, 1) }
          .to raise_error(NotImplementedError, "子类必须实现 process_valid_row 方法")
      end
    end
  end
end