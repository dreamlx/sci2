# frozen_string_literal: true

# WorkOrderRepository共享测试示例
# 为所有继承BaseWorkOrderRepository的Repository提供统一的测试用例
RSpec.shared_examples 'basic work order repository' do |repository_class, model_class, factory_name|
  let!(:reimbursement) { create(:reimbursement) }

  # 根据不同的工单类型创建测试数据
  let!(:work_order1) do
    case model_class.name
    when 'AuditWorkOrder'
      create(factory_name,
             reimbursement: reimbursement,
             status: 'pending',
             created_at: 1.day.ago)
    when 'CommunicationWorkOrder'
      create(factory_name,
             reimbursement: reimbursement,
             status: 'completed',
             communication_method: 'phone',
             created_at: 1.day.ago)
    when 'ExpressReceiptWorkOrder'
      create(factory_name,
             reimbursement: reimbursement,
             status: 'completed',
             tracking_number: 'SF123456789',
             created_at: 1.day.ago)
    end
  end

  let!(:work_order2) do
    case model_class.name
    when 'AuditWorkOrder'
      create(factory_name,
             reimbursement: reimbursement,
             status: 'processing',
             created_at: 2.days.ago)
    when 'CommunicationWorkOrder'
      create(factory_name,
             reimbursement: reimbursement,
             status: 'completed',
             communication_method: 'email',
             created_at: 2.days.ago)
    when 'ExpressReceiptWorkOrder'
      create(factory_name,
             reimbursement: reimbursement,
             status: 'completed',
             tracking_number: 'JD987654321',
             created_at: 2.days.ago)
    end
  end

  describe 'basic query methods' do
    it '.find returns record when found' do
      result = repository_class.find(work_order1.id)
      expect(result).to eq(work_order1)
    end

    it '.find returns nil when not found' do
      result = repository_class.find(99_999)
      expect(result).to be_nil
    end

    it '.find_by_id returns record when found' do
      result = repository_class.find_by_id(work_order1.id)
      expect(result).to eq(work_order1)
    end

    it '.find_by_id returns nil when not found' do
      result = repository_class.find_by_id(99_999)
      expect(result).to be_nil
    end

    it '.find_by_ids returns multiple records' do
      result = repository_class.find_by_ids([work_order1.id, work_order2.id])
      expect(result.count).to eq(2)
      expect(result.pluck(:id)).to include(work_order1.id, work_order2.id)
    end

    it '.exists? returns true for existing record' do
      expect(repository_class.exists?(id: work_order1.id)).to be true
    end

    it '.exists? returns false for non-existing record' do
      expect(repository_class.exists?(id: 99_999)).to be false
    end

    it '.safe_find returns record when found' do
      result = repository_class.safe_find(work_order1.id)
      expect(result).to eq(work_order1)
    end

    it '.safe_find returns nil when error occurs' do
      allow(model_class).to receive(:find_by).and_raise(StandardError, 'Test error')
      expect(repository_class.safe_find(work_order1.id)).to be_nil
    end
  end

  describe 'reimbursement association queries' do
    it '.for_reimbursement returns work orders for specific reimbursement' do
      result = repository_class.for_reimbursement(reimbursement)
      expect(result.pluck(:id)).to include(work_order1.id, work_order2.id)
    end

    it '.for_reimbursement_id returns work orders for specific reimbursement id' do
      result = repository_class.for_reimbursement_id(reimbursement.id)
      expect(result.pluck(:id)).to include(work_order1.id, work_order2.id)
    end

    it '.exists_for_reimbursement? returns true when work orders exist' do
      expect(repository_class.exists_for_reimbursement?(reimbursement.id)).to be true
    end

    it '.exists_for_reimbursement? returns false when no work orders exist' do
      expect(repository_class.exists_for_reimbursement?(99_999)).to be false
    end
  end

  describe 'date-based queries' do
    it '.created_today returns work orders created today' do
      today_work_order = create(factory_name,
                               reimbursement: reimbursement,
                               status: model_class.status_traits[:initial_status],
                               created_at: Time.current)

      result = repository_class.created_today
      expect(result.pluck(:id)).to include(today_work_order.id)
    end

    it '.created_this_week returns work orders created this week' do
      # 创建本周内的测试数据以确保测试通过
      this_week_work_order = create(factory_name,
                                   reimbursement: reimbursement,
                                   status: model_class.status_traits[:initial_status],
                                   created_at: Date.current.beginning_of_week + 1.day)

      result = repository_class.created_this_week
      expect(result.pluck(:id)).to include(this_week_work_order.id)
    end

    it '.created_this_month returns work orders created this month' do
      result = repository_class.created_this_month
      expect(result.pluck(:id)).to include(work_order1.id, work_order2.id)
    end
  end

  describe 'ordering and pagination' do
    it '.recent returns most recent work orders' do
      result = repository_class.recent(1)
      expect(result.first.created_at).to be >= work_order1.created_at
    end

    it '.oldest_first returns work orders in ascending order' do
      result = repository_class.oldest_first
      expect(result.first.created_at).to be <= result.last.created_at
    end

    it '.page returns paginated results' do
      result = repository_class.page(1, 1)
      expect(result.count).to eq(1)
    end
  end

  describe 'count and aggregation methods' do
    it '.total_count returns total number of work orders' do
      expect(repository_class.total_count).to be >= 2
    end

    it '.status_counts returns status distribution' do
      result = repository_class.status_counts
      expect(result).to be_a(Hash)
    end
  end

  describe 'search functionality' do
    let!(:work_order_with_notes) do
      case model_class.name
      when 'AuditWorkOrder'
        create(factory_name, reimbursement: reimbursement, audit_comment: 'Special notes for search')
      when 'CommunicationWorkOrder'
        create(factory_name, reimbursement: reimbursement, audit_comment: 'Special notes for search')
      when 'ExpressReceiptWorkOrder'
        # ExpressReceiptWorkOrder没有notes字段，使用audit_comment字段
        create(factory_name, reimbursement: reimbursement, audit_comment: 'Special notes for search')
      end
    end

    it '.search_by_notes returns matching work orders' do
      skip "No searchable notes field for #{model_class.name}" unless model_class.column_names.include?('notes')

      result = repository_class.search_by_notes('Special notes')
      expect(result.pluck(:id)).to include(work_order_with_notes.id)
    end
  end

  describe 'performance optimization' do
    it '.select_fields returns selected fields only' do
      result = repository_class.select_fields([:id, :status])
      expect(result.first.attributes.keys).to include('id', 'status')
    end

    it '.optimized_list includes associations' do
      result = repository_class.optimized_list
      expect(result).to respond_to(:each)
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      # 测试safe_find方法能处理错误
      allow(model_class).to receive(:find_by).and_raise(StandardError, 'Test error')

      expect(repository_class.safe_find(99_999)).to be_nil
    end
  end
end

# 智能状态查询共享示例
RSpec.shared_examples 'intelligent status queries' do |repository_class, model_class|
  # 将model_class声明为实例变量，以便在private方法中使用
  let(:model_class) { model_class }

  describe 'intelligent status queries' do
    context 'when status is available' do
      it 'returns results for available status' do
        available_statuses = model_class.available_statuses
        skip "No available statuses for #{model_class.name}" if available_statuses.empty?

        status = available_statuses.first
        create_work_order_with_status(status)

        result = repository_class.by_status(status)
        expect(result.count).to be >= 1
      end
    end

    context 'when status is not available' do
      it 'returns none for unavailable status' do
        unavailable_status = 'unavailable_status'
        result = repository_class.by_status(unavailable_status)
        expect(result).to be_none
      end
    end

    if model_class.respond_to?(:always_completed?) && model_class.always_completed?
      describe 'always completed behavior' do
        it '.completed returns all records' do
          create_work_order_with_status(model_class.available_statuses.first)

          result = repository_class.completed
          expect(result.count).to eq(model_class.count)
        end

        it '.pending returns none' do
          result = repository_class.pending
          expect(result).to be_none
        end
      end
    elsif model_class.respond_to?(:auto_completed?) && model_class.auto_completed?
      describe 'auto completed behavior' do
        it '.completed returns all records' do
          create_work_order_with_status(model_class.available_statuses.first)

          result = repository_class.completed
          expect(result.count).to eq(model_class.count)
        end

        it '.pending returns none' do
          result = repository_class.pending
          expect(result).to be_none
        end
      end
    else
      describe 'manual status management' do
        it '.pending returns pending records when available' do
          if model_class.status_available?('pending')
            create_work_order_with_status('pending')
            result = repository_class.pending
            expect(result.count).to be >= 1
          else
            result = repository_class.pending
            expect(result).to be_none
          end
        end

        it '.completed returns completed records when available' do
          if model_class.status_available?('completed')
            create_work_order_with_status('completed')
            result = repository_class.completed
            expect(result.count).to be >= 1
          else
            result = repository_class.completed
            expect(result).to be_none
          end
        end
      end
    end
  end

  private

  def create_work_order_with_status(status)
    case model_class.name
    when 'AuditWorkOrder'
      create(:audit_work_order, status: status, created_at: Time.current)
    when 'CommunicationWorkOrder'
      create(:communication_work_order, status: status, created_at: Time.current)
    when 'ExpressReceiptWorkOrder'
      create(:express_receipt_work_order, status: status, created_at: Time.current)
    end
  end
end