# frozen_string_literal: true

# AuditWorkOrderRepository - 审核工单Repository
# 继承BaseWorkOrderRepository，只保留审核特有的业务逻辑
class AuditWorkOrderRepository < BaseWorkOrderRepository
  class << self
    # 审核结果查询 - 特有业务逻辑
    def by_audit_result(audit_result)
      model_class.where(audit_result: audit_result)
    end

    def approved
      model_class.where(audit_result: 'approved')
    end

    def rejected
      model_class.where(audit_result: 'rejected')
    end

    def pending_audit
      model_class.where(audit_result: nil)
    end

    # VAT验证查询 - 特有业务逻辑
    def vat_verified
      model_class.where(vat_verified: true)
    end

    def vat_not_verified
      model_class.where(vat_verified: false)
    end

    def by_vat_verified(vat_verified)
      model_class.where(vat_verified: vat_verified)
    end

    # 审核状态查询 - 补充基类方法
    def status_approved
      model_class.where(status: 'approved')
    end

    def status_rejected
      model_class.where(status: 'rejected')
    end

    # 组合查询 - 审核特有业务逻辑
    def approved_and_vat_verified
      approved.where(vat_verified: true)
    end

    def rejected_with_comments
      rejected.where.not(audit_comment: [nil, ''])
    end

    def pending_audit_vat_verified
      pending_audit.where(vat_verified: true)
    end

    # 审核日期查询 - 特有业务逻辑
    def audited_today
      model_class.where(audit_date: Date.current.all_day)
    end

    def audited_this_week
      model_class.where(audit_date: Date.current.beginning_of_week..Date.current.end_of_week)
    end

    def audited_this_month
      model_class.where(audit_date: Date.current.beginning_of_month..Date.current.end_of_month)
    end

    def by_audit_date_range(start_date, end_date)
      model_class.where(audit_date: start_date..end_date)
    end

    # 计数方法 - 审核特有
    def approved_count
      approved.count
    end

    def rejected_count
      rejected.count
    end

    def pending_audit_count
      pending_audit.count
    end

    def vat_verified_count
      vat_verified.count
    end

    def vat_not_verified_count
      vat_not_verified.count
    end

    def audit_result_counts
      model_class.group(:audit_result).count
    end

    # 搜索功能 - 审核特有
    def search_by_audit_comment(query)
      return model_class.none if query.blank?

      model_class.where('audit_comment LIKE ?', "%#{query}%")
    end

    # 排序查询 - 审核特有
    def recent_audits(limit = 10)
      model_class.where.not(audit_date: nil).order(audit_date: :desc).limit(limit)
    end

    # 存在性检查 - 审核特有
    def has_approved_audit?(reimbursement_id)
      for_reimbursement_id(reimbursement_id).approved.exists?
    end

    def has_rejected_audit?(reimbursement_id)
      for_reimbursement_id(reimbursement_id).rejected.exists?
    end

    # 性能优化 - 重写基类方法以包含审核特有关联
    def optimized_list
      model_class.includes(:reimbursement, :creator)
    end

    def with_associations
      model_class.includes(:reimbursement, :creator)
    end

    private

    # 返回对应的Model类
    def model_class
      AuditWorkOrder
    end
  end
end