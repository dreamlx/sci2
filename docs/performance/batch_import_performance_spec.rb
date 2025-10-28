# spec/performance/batch_import_performance_spec.rb
require 'rails_helper'

RSpec.describe 'BatchImportManager Performance', type: :performance do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_type) { create(:fee_type) }

  before do
    # 清理测试数据
    FeeDetail.delete_all
    Current.admin_user = admin_user
  end

  describe '批量导入性能基准测试' do
    context '小批量数据导入 (<1000条)' do
      let(:small_batch_size) { 100 }
      let(:small_test_data) { generate_test_data(small_batch_size) }

      it '在合理时间内完成小批量导入' do
        manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)

        start_time = Time.current
        result = manager.batch_import(small_test_data) do |batch|
          process_fee_details_batch(batch)
        end
        end_time = Time.current

        duration = end_time - start_time
        records_per_second = small_batch_size / duration

        expect(duration).to be < 2.0 # 应该在2秒内完成
        expect(records_per_second).to be > 50 # 每秒至少处理50条记录
        expect(result[:success]).to be true
        expect(result[:processed]).to eq(small_batch_size)
      end

      it '内存使用保持在合理范围内' do
        initial_memory = get_memory_usage

        manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)
        manager.batch_import(small_test_data) do |batch|
          process_fee_details_batch(batch)
        end

        final_memory = get_memory_usage
        memory_increase = final_memory - initial_memory

        # 内存增长不应该超过50MB
        expect(memory_increase).to be < 50 * 1024 * 1024
      end
    end

    context '中批量数据导入 (1000-5000条)' do
      let(:medium_batch_size) { 2500 }
      let(:medium_test_data) { generate_test_data(medium_batch_size) }

      it '高效处理中等规模数据' do
        manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)

        start_time = Time.current
        result = manager.batch_import(medium_test_data) do |batch|
          process_fee_details_batch(batch)
        end
        end_time = Time.current

        duration = end_time - start_time
        records_per_second = medium_batch_size / duration

        expect(duration).to be < 10.0 # 应该在10秒内完成
        expect(records_per_second).to be > 250 # 每秒至少处理250条记录
        expect(result[:success]).to be true
        expect(result[:processed]).to eq(medium_batch_size)
      end

      it '正确分批处理数据' do
        manager = BatchImportManager.new(FeeDetail, batch_size: 1000)

        batch_count = 0
        result = manager.batch_import(medium_test_data) do |batch|
          batch_count += 1
          expect(batch.size).to be <= 1000
          process_fee_details_batch(batch)
        end

        # 2500条记录，每批1000条，应该分成3批
        expect(batch_count).to eq(3)
        expect(result[:success]).to be true
      end
    end

    context '大批量数据导入 (>5000条)' do
      let(:large_batch_size) { 10000 }
      let(:large_test_data) { generate_test_data(large_batch_size) }

      it '处理大规模数据时保持性能' do
        manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)

        start_time = Time.current
        result = manager.batch_import(large_test_data) do |batch|
          process_fee_details_batch(batch)
        end
        end_time = Time.current

        duration = end_time - start_time
        records_per_second = large_batch_size / duration

        expect(duration).to be < 30.0 # 应该在30秒内完成
        expect(records_per_second).to be > 300 # 每秒至少处理300条记录
        expect(result[:success]).to be true
        expect(result[:processed]).to eq(large_batch_size)
      end

      it '使用优化的批量大小' do
        manager = BatchImportManager.new(FeeDetail, optimization_level: :aggressive)

        # aggressive模式应该使用更大的批量大小
        expect(manager.batch_size).to be > 1000
      end
    end
  end

  describe '性能优化级别对比' do
    let(:test_data) { generate_test_data(2000) }

    context '不同优化级别性能对比' do
      it 'aggressive模式比moderate模式更快' do
        # 测试moderate模式
        moderate_manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)
        moderate_start = Time.current
        moderate_manager.batch_import(test_data) { |batch| process_fee_details_batch(batch) }
        moderate_end = Time.current
        moderate_duration = moderate_end - moderate_start

        # 清理数据
        FeeDetail.delete_all

        # 测试aggressive模式
        aggressive_manager = BatchImportManager.new(FeeDetail, optimization_level: :aggressive)
        aggressive_start = Time.current
        aggressive_manager.batch_import(test_data) { |batch| process_fee_details_batch(batch) }
        aggressive_end = Time.current
        aggressive_duration = aggressive_end - aggressive_start

        # aggressive模式应该更快（至少快20%）
        expect(aggressive_duration).to be < moderate_duration * 0.8
      end

      it 'safe模式提供数据一致性保证' do
        safe_manager = BatchImportManager.new(FeeDetail, optimization_level: :safe)

        result = safe_manager.batch_import(test_data) do |batch|
          process_fee_details_batch(batch)
        end

        expect(result[:success]).to be true
        expect(FeeDetail.count).to eq(test_data.size)

        # 验证数据完整性
        FeeDetail.all.each do |fee_detail|
          expect(fee_detail.document_number).to be_present
          expect(fee_detail.original_amount).to be > 0
          expect(fee_detail.fee_date).to be_present
        end
      end
    end
  end

  describe '并发导入安全性测试' do
    let(:concurrent_test_data) { generate_test_data(1000) }

    it '支持并发导入操作' do
      threads = []
      results = []

      3.times do |i|
        threads << Thread.new do
          # 为每个线程创建独立的数据集
          thread_data = concurrent_test_data.map.with_index do |item, index|
            item.merge(thread_id: i, unique_id: "#{i}_#{index}")
          end

          manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)
          result = manager.batch_import(thread_data) do |batch|
            process_concurrent_fee_details_batch(batch)
          end

          results << result
        end
      end

      threads.each(&:join)

      # 验证所有线程都成功
      results.each do |result|
        expect(result[:success]).to be true
      end

      # 验证总记录数
      expect(FeeDetail.count).to eq(concurrent_test_data.size * 3)
    end

    it '避免数据竞争条件' do
      # 创建相同的测试数据，模拟竞争条件
      threads = []

      5.times do
        threads << Thread.new do
          manager = BatchImportManager.new(FeeDetail, optimization_level: :safe)
          manager.batch_import(concurrent_test_data.first(100)) do |batch|
            process_fee_details_batch(batch)
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error

      # 验证数据一致性
      expect(FeeDetail.where(document_number: concurrent_test_data.first[:document_number]).count).to be >= 1
    end
  end

  describe '数据库查询优化测试' do
    let(:query_test_data) { generate_test_data(5000) }

    it '使用批量插入减少数据库查询' do
      # 监控数据库查询次数
      query_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        query_count += 1
      end

      manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)
      manager.batch_import(query_test_data) do |batch|
        process_fee_details_batch(batch)
      end

      # 查询次数应该显著少于记录数量（使用批量插入）
      expect(query_count).to be < query_test_data.size / 10
    end

    it '使用insert_all进行高性能插入' do
      manager = BatchImportManager.new(FeeDetail, optimization_level: :aggressive)

      # 验证使用了insert_all方法
      expect_any_instance_of(FeeDetail).to receive(:insert_all).and_call_original

      manager.batch_import(query_test_data.first(100)) do |batch|
        manager.send(:bulk_insert, batch)
      end
    end
  end

  describe '内存和资源管理测试' do
    it '及时释放大对象内存' do
      large_data = generate_test_data(10000)

      manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)

      # 测试内存使用
      initial_memory = get_memory_usage

      manager.batch_import(large_data) do |batch|
        process_fee_details_batch(batch)
        # 处理完批次后，内存应该被释放
        GC.start
      end

      final_memory = get_memory_usage
      memory_growth = final_memory - initial_memory

      # 内存增长应该在合理范围内
      expect(memory_growth).to be < 100 * 1024 * 1024 # 100MB
    end

    it '正确处理异常情况下的资源清理' do
      manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)

      # 模拟处理过程中的异常
      expect(manager).to receive(:process_batch).and_raise(StandardError, 'Test error')

      result = manager.batch_import(generate_test_data(100))

      expect(result[:success]).to be false
      expect(result[:errors]).to include('Test error')

      # 验证资源被正确清理
      expect(manager.instance_variable_get(:@current_batch)).to be_nil
    end
  end

  private

  def generate_test_data(count)
    Array.new(count) do |index|
      {
        document_number: "INV#{index.to_s.rjust(6, '0')}",
        fee_type_id: fee_type.id,
        original_amount: (rand(100.0..1000.0)).round(2),
        fee_date: Date.today - rand(0..365),
        description: "测试费用#{index}",
        verification_status: 'pending',
        creator_id: admin_user.id
      }
    end
  end

  def process_fee_details_batch(batch)
    FeeDetail.insert_all(batch.map(&:attributes_for_bulk_insert))
  end

  def process_concurrent_fee_details_batch(batch)
    attributes_list = batch.map do |item|
      # 为并发测试添加唯一标识
      attrs = item.except(:thread_id, :unique_id)
      attrs[:description] = "#{attrs[:description]}_#{item[:unique_id]}"
      attrs.attributes_for_bulk_insert
    end

    FeeDetail.insert_all(attributes_list)
  end

  def get_memory_usage
    # 获取当前Ruby进程的内存使用量（字节）
    GC.start
    ObjectSpace.count_objects * 40 # 粗略估算
  end
end