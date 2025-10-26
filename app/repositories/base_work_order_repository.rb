# frozen_string_literal: true

# BaseWorkOrderRepository - 工单Repository基类
# 提供所有工单类型的通用查询方法，消除代码重复
class BaseWorkOrderRepository
  class << self
    # 基础查询方法
    def find(id)
      model_class.find_by(id: id)
    end

    def find_by_id(id)
      model_class.find_by(id: id)
    end

    def find_by_ids(ids)
      model_class.where(id: ids)
    end

    def exists?(id:)
      model_class.exists?(id: id)
    end

    def safe_find(id)
      find(id)
    rescue StandardError => e
      Rails.logger.error "#{self.name}.safe_find error: #{e.message}"
      nil
    end

    def safe_find_by_id(id)
      find_by_id(id)
    rescue StandardError => e
      Rails.logger.error "#{self.name}.safe_find_by_id error: #{e.message}"
      nil
    end

    # 智能状态查询方法 - 基于Model状态特性
    def by_status(status)
      return model_class.none unless status_available?(status)
      model_class.where(status: status)
    end

    def pending
      return model_class.none unless status_available?('pending')
      model_class.where(status: 'pending')
    end

    def processing
      return model_class.none unless status_available?('processing')
      model_class.where(status: 'processing')
    end

    def approved
      return model_class.none unless status_available?('approved')
      model_class.where(status: 'approved')
    end

    def rejected
      return model_class.none unless status_available?('rejected')
      model_class.where(status: 'rejected')
    end

    def completed
      if model_class.always_completed? || model_class.auto_completed?
        model_class.all # 这些类型的工单都是completed状态
      elsif status_available?('completed')
        model_class.where(status: 'completed')
      else
        model_class.none
      end
    end

    # 报销单关联查询
    def for_reimbursement(reimbursement)
      model_class.where(reimbursement_id: reimbursement.id)
    end

    def for_reimbursement_id(reimbursement_id)
      model_class.where(reimbursement_id: reimbursement_id)
    end

    def by_reimbursement(reimbursement)
      for_reimbursement(reimbursement)
    end

    def by_document_number(document_number)
      reimbursement = Reimbursement.find_by(invoice_number: document_number)
      return model_class.none unless reimbursement

      for_reimbursement(reimbursement)
    end

    def exists_for_reimbursement?(reimbursement_id)
      for_reimbursement_id(reimbursement_id).exists?
    end

    # 状态特性辅助方法
    def available_statuses
      model_class.available_statuses
    end

    def status_available?(status)
      model_class.status_available?(status)
    end

    # 智能范围查询
    def active_work_orders
      if model_class.always_completed? || model_class.auto_completed?
        model_class.none # 这些类型没有活跃状态
      else
        model_class.where.not(status: model_class.final_statuses)
      end
    end

    def finished_work_orders
      if model_class.always_completed? || model_class.auto_completed?
        model_class.all # 所有都是完成状态
      else
        model_class.where(status: model_class.final_statuses)
      end
    end

    # 日期查询
    def created_today
      model_class.where(created_at: Date.current.all_day)
    end

    def created_this_week
      model_class.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
    end

    def created_this_month
      model_class.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
    end

    # 排序和分页
    def recent(limit = 10)
      model_class.order(created_at: :desc).limit(limit)
    end

    def oldest_first
      model_class.order(created_at: :asc)
    end

    def page(page_number, per_page = 20)
      model_class.limit(per_page).offset((page_number - 1) * per_page)
    end

    # 性能优化方法
    def select_fields(fields)
      model_class.select(fields)
    end

    def optimized_list
      model_class.includes(:reimbursement, :assignee)
    end

    # 智能计数方法 - 基于Model状态特性
    def total_count
      model_class.count
    end

    def status_counts
      if model_class.always_completed? || model_class.auto_completed?
        { 'completed' => model_class.count }
      else
        model_class.group(:status).count
      end
    end

    def pending_count
      if model_class.always_completed? || model_class.auto_completed?
        0
      else
        pending.count
      end
    end

    def processing_count
      if model_class.always_completed? || model_class.auto_completed?
        0
      else
        processing.count
      end
    end

    def completed_count
      if model_class.always_completed? || model_class.auto_completed?
        model_class.count
      else
        completed.count
      end
    end

    # 搜索功能
    def search_by_notes(query)
      return model_class.none if query.blank?

      model_class.where("notes ILIKE ?", "%#{query}%")
    end

    # 分配相关查询
    def assigned_to(assignee_id)
      model_class.where(assignee_id: assignee_id)
    end

    def unassigned
      model_class.where(assignee_id: nil)
    end

    private

    # 子类必须实现此方法返回对应的Model类
    def model_class
      raise NotImplementedError, "子类必须实现model_class方法"
    end
  end
end