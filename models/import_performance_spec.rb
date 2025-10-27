# spec/models/import_performance_spec.rb
require 'rails_helper'

RSpec.describe ImportPerformance do
  describe 'validations' do
    it 'is valid with valid attributes' do
      import_performance = build(:import_performance,
        operation_type: 'batch_import',
        elapsed_time: 10.5,
        record_count: 100
      )
      expect(import_performance).to be_valid
    end

    it 'is invalid without operation_type' do
      import_performance = build(:import_performance, operation_type: nil)
      expect(import_performance).not_to be_valid
      expect(import_performance.errors[:operation_type]).to include("不能为空")
    end

    it 'is invalid without elapsed_time' do
      import_performance = build(:import_performance, elapsed_time: nil)
      expect(import_performance).not_to be_valid
      expect(import_performance.errors[:elapsed_time]).to include("不能为空")
    end

    it 'is invalid with elapsed_time <= 0' do
      import_performance = build(:import_performance, elapsed_time: 0)
      expect(import_performance).not_to be_valid
      expect(import_performance.errors[:elapsed_time]).to include("必须大于 0")
    end

    it 'is invalid without record_count' do
      import_performance = build(:import_performance, record_count: nil)
      expect(import_performance).not_to be_valid
      expect(import_performance.errors[:record_count]).to include("不能为空")
    end

    it 'is invalid with record_count < 0' do
      import_performance = build(:import_performance, record_count: -1)
      expect(import_performance).not_to be_valid
      expect(import_performance.errors[:record_count]).to include("必须大于或等于 0")
    end
  end

  describe 'scopes' do
    let!(:import1) { create(:import_performance, operation_type: 'batch_import', optimization_level: 'basic') }
    let!(:import2) { create(:import_performance, operation_type: 'single_import', optimization_level: 'advanced') }
    let!(:import3) { create(:import_performance, operation_type: 'batch_import', optimization_level: 'advanced', created_at: 2.hours.ago) }

    describe '.by_operation_type' do
      it 'returns imports by operation type' do
        batch_imports = ImportPerformance.by_operation_type('batch_import')
        expect(batch_imports).to include(import1, import3)
        expect(batch_imports).not_to include(import2)
      end
    end

    describe '.by_optimization_level' do
      it 'returns imports by optimization level' do
        advanced_imports = ImportPerformance.by_optimization_level('advanced')
        expect(advanced_imports).to include(import2, import3)
        expect(advanced_imports).not_to include(import1)
      end
    end

    describe '.recent' do
      it 'returns imports ordered by created_at desc' do
        recent_imports = ImportPerformance.recent
        expect(recent_imports.first).to be_created_before(recent_imports.last)
      end
    end
  end

  describe 'instance methods' do
    let(:import_performance) { create(:import_performance, elapsed_time: 10.0, record_count: 500) }

    describe '#records_per_second' do
      it 'calculates records per second correctly' do
        expect(import_performance.records_per_second).to eq(50.0)
      end

      it 'returns 0 when elapsed_time is 0' do
        import_performance.update!(elapsed_time: 0)
        expect(import_performance.records_per_second).to eq(0)
      end

      it 'returns 0 when record_count is 0' do
        import_performance.update!(record_count: 0)
        expect(import_performance.records_per_second).to eq(0)
      end
    end

    describe '#formatted_elapsed_time' do
      it 'formats elapsed time correctly' do
        expect(import_performance.formatted_elapsed_time).to eq("10.0秒")
      end

      it 'handles decimal values' do
        import_performance.update!(elapsed_time: 10.567)
        expect(import_performance.formatted_elapsed_time).to eq("10.57秒")
      end
    end

    describe '#parsed_optimization_settings' do
      it 'returns empty hash when optimization_settings is blank' do
        import_performance.update!(optimization_settings: nil)
        expect(import_performance.parsed_optimization_settings).to eq({})
      end

      it 'returns parsed JSON when optimization_settings is valid JSON' do
        settings = { batch_size: 100, optimize: true }
        import_performance.update!(optimization_settings: settings.to_json)
        expect(import_performance.parsed_optimization_settings).to eq(settings)
      end

      it 'returns empty hash when optimization_settings is invalid JSON' do
        import_performance.update!(optimization_settings: 'invalid json')
        expect(import_performance.parsed_optimization_settings).to eq({})
      end
    end

    describe '#performance_grade' do
      it 'returns C for low performance (0-50 rps)' do
        import_performance.update!(elapsed_time: 10.0, record_count: 250) # 25 rps
        expect(import_performance.performance_grade).to eq('C')
      end

      it 'returns B for medium performance (51-100 rps)' do
        import_performance.update!(elapsed_time: 10.0, record_count: 750) # 75 rps
        expect(import_performance.performance_grade).to eq('B')
      end

      it 'returns A for high performance (101-200 rps)' do
        import_performance.update!(elapsed_time: 10.0, record_count: 1500) # 150 rps
        expect(import_performance.performance_grade).to eq('A')
      end

      it 'returns S for excellent performance (200+ rps)' do
        import_performance.update!(elapsed_time: 10.0, record_count: 2500) # 250 rps
        expect(import_performance.performance_grade).to eq('S')
      end

      it 'returns C when performance is exactly 50 rps' do
        import_performance.update!(elapsed_time: 10.0, record_count: 500) # 50 rps
        expect(import_performance.performance_grade).to eq('C')
      end

      it 'returns B when performance is exactly 51 rps' do
        import_performance.update!(elapsed_time: 10.0, record_count: 510) # 51 rps
        expect(import_performance.performance_grade).to eq('B')
      end

      it 'returns A when performance is exactly 101 rps' do
        import_performance.update!(elapsed_time: 10.0, record_count: 1010) # 101 rps
        expect(import_performance.performance_grade).to eq('A')
      end
    end
  end

  describe 'class methods' do
    let!(:import1) { create(:import_performance, operation_type: 'batch_import', elapsed_time: 10.0, record_count: 1000, optimization_level: 'basic') }
    let!(:import2) { create(:import_performance, operation_type: 'batch_import', elapsed_time: 20.0, record_count: 2000, optimization_level: 'advanced') }
    let!(:import3) { create(:import_performance, operation_type: 'single_import', elapsed_time: 5.0, record_count: 250, optimization_level: 'basic') }

    describe '.performance_stats' do
      context 'without operation_type filter' do
        it 'returns overall performance statistics' do
          stats = ImportPerformance.performance_stats

          expect(stats[:total_imports]).to eq(3)
          expect(stats[:avg_elapsed_time]).to eq(11.67) # (10.0 + 20.0 + 5.0) / 3
          expect(stats[:total_records]).to eq(3250) # 1000 + 2000 + 250
          expect(stats[:optimization_levels]).to eq({ 'basic' => 2, 'advanced' => 1 })
        end
      end

      context 'with operation_type filter' do
        it 'returns filtered performance statistics' do
          stats = ImportPerformance.performance_stats('batch_import')

          expect(stats[:total_imports]).to eq(2)
          expect(stats[:avg_elapsed_time]).to eq(15.0) # (10.0 + 20.0) / 2
          expect(stats[:total_records]).to eq(3000) # 1000 + 2000
          expect(stats[:optimization_levels]).to eq({ 'basic' => 1, 'advanced' => 1 })
        end
      end

      context 'when no imports exist' do
        before { ImportPerformance.delete_all }

        it 'returns zero statistics' do
          stats = ImportPerformance.performance_stats

          expect(stats[:total_imports]).to eq(0)
          expect(stats[:avg_elapsed_time]).to eq(0)
          expect(stats[:avg_records_per_second]).to eq(0)
          expect(stats[:total_records]).to eq(0)
          expect(stats[:optimization_levels]).to eq({})
        end
      end
    end
  end

  describe 'associations and relationships' do
    it 'can belong to other models if needed' do
      # This would be useful if we want to track performance for specific users or reimbursements
      import_performance = build(:import_performance)
      expect(import_performance).to respond_to(:save)
    end
  end

  describe 'edge cases' do
    it 'handles very large numbers correctly' do
      large_import = build(:import_performance,
        elapsed_time: 1.0,
        record_count: 1000000
      )
      expect(large_import.records_per_second).to eq(1000000.0)
      expect(large_import.performance_grade).to eq('S')
    end

    it 'handles very small decimal values' do
      small_import = build(:import_performance,
        elapsed_time: 0.01,
        record_count: 1
      )
      expect(small_import.records_per_second).to eq(100.0)
      expect(small_import.performance_grade).to eq('A')
    end

    it 'handles rounding correctly' do
      import = build(:import_performance,
        elapsed_time: 3.0,
        record_count: 100
      )
      expect(import.records_per_second).to eq(33.33) # 100 / 3.0
    end
  end

  describe 'JSON handling' do
    it 'handles complex JSON structures' do
      complex_settings = {
        batch_size: 100,
        optimize: true,
        features: ['parallel', 'caching'],
        config: {
          timeout: 30,
          retries: 3
        }
      }

      import = create(:import_performance, optimization_settings: complex_settings.to_json)
      parsed = import.parsed_optimization_settings

      expect(parsed).to eq(complex_settings)
      expect(parsed['features']).to include('parallel', 'caching')
      expect(parsed['config']['timeout']).to eq(30)
    end

    it 'handles malformed JSON gracefully' do
      malformed_jsons = [
        '{ unclosed json',
        '{"key": "value",}',
        'null',
        '',
        'undefined',
        '{"nested": {"incomplete": true'
      ]

      malformed_jsons.each do |json|
        import = create(:import_performance, optimization_settings: json)
        expect(import.parsed_optimization_settings).to eq({})
      end
    end
  end
end