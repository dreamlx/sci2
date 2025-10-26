# frozen_string_literal: true

# CommunicationWorkOrderRepository - 沟通工单Repository
# 继承BaseWorkOrderRepository，只保留沟通特有的业务逻辑
class CommunicationWorkOrderRepository < BaseWorkOrderRepository
  class << self
    # 沟通方式查询 - 特有业务逻辑
    def by_communication_method(method)
      model_class.where(communication_method: method)
    end

    # 沟通记录查询 - 特有业务逻辑
    def with_comments
      model_class.where.not(audit_comment: [nil, ''])
    end

    def search_by_audit_comment(query)
      return model_class.none if query.blank?

      model_class.where('audit_comment LIKE ?', "%#{query}%")
    end

    # 计数方法 - 沟通特有
    def communication_method_counts
      model_class.group(:communication_method).count
    end

    # 排序查询 - 沟通特有
    def recent_first
      model_class.order(created_at: :desc)
    end

    # 性能优化 - 重写基类方法以包含沟通特有关联
    def optimized_list
      model_class.includes(:reimbursement, :creator)
    end

    def with_associations
      model_class.includes(:reimbursement, :creator)
    end

    private

    # 返回对应的Model类
    def model_class
      CommunicationWorkOrder
    end
  end
end