# frozen_string_literal: true

# ExpressReceiptWorkOrderRepository - 快递收单工单Repository
# 继承BaseWorkOrderRepository，只保留快递收单特有的业务逻辑
class ExpressReceiptWorkOrderRepository < BaseWorkOrderRepository
  class << self
    # 快递单号查询 - 特有业务逻辑
    def by_tracking_number(tracking_number)
      model_class.where(tracking_number: tracking_number)
    end

    def find_by_tracking_number(tracking_number)
      model_class.find_by(tracking_number: tracking_number)
    end

    # 填充ID查询 - 特有业务逻辑
    def by_filling_id(filling_id)
      model_class.where(filling_id: filling_id)
    end

    def find_by_filling_id(filling_id)
      model_class.find_by(filling_id: filling_id)
    end

    # 快递公司查询 - 特有业务逻辑
    def by_courier_name(courier_name)
      model_class.where(courier_name: courier_name)
    end

    # 状态查询 - 快递收单特殊处理（总是completed状态）
    def all_completed
      model_class.all # All express receipts should be completed
    end

    # 收货日期查询 - 特有业务逻辑
    def received_today
      model_class.where(received_at: Date.current.all_day)
    end

    def received_this_week
      model_class.where(received_at: Date.current.beginning_of_week..Date.current.end_of_week)
    end

    def received_this_month
      model_class.where(received_at: Date.current.beginning_of_month..Date.current.end_of_month)
    end

    def by_received_date_range(start_date, end_date)
      model_class.where(received_at: start_date..end_date)
    end

    # 计数方法 - 快递收单特有
    def courier_counts
      model_class.group(:courier_name).count
    end

    def received_count_by_date(date)
      model_class.where(received_at: date.all_day).count
    end

    # 排序查询 - 快递收单特有
    def recent_received(limit = 10)
      model_class.order(received_at: :desc).limit(limit)
    end

    def recent_first
      model_class.order(created_at: :desc)
    end

    # 存在性检查 - 快递收单特有
    def exists_by_tracking_number?(tracking_number)
      by_tracking_number(tracking_number).exists?
    end

    def exists_by_filling_id?(filling_id)
      by_filling_id(filling_id).exists?
    end

    # 错误处理 - 快递收单特有
    def safe_find_by_tracking_number(tracking_number)
      find_by_tracking_number(tracking_number)
    rescue StandardError => e
      Rails.logger.error "#{self.name}.safe_find_by_tracking_number error: #{e.message}"
      nil
    end

    # 性能优化 - 重写基类方法以包含快递收单特有关联
    def optimized_list
      model_class.includes(:reimbursement, :creator)
    end

    def with_associations
      model_class.includes(:reimbursement, :creator)
    end

    private

    # 返回对应的Model类
    def model_class
      ExpressReceiptWorkOrder
    end
  end
end