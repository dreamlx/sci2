# app/services/service_registry.rb
class ServiceRegistry
  class << self
    # 获取服务实例
    def get_service(service_class, *args)
      # 确保服务类存在
      raise ArgumentError, "未知的服务类: #{service_class}" unless service_class_exists?(service_class)

      # 获取服务类常量
      service_klass = service_class.is_a?(Class) ? service_class : service_class.to_s.constantize

      # 实例化服务
      instantiate_service(service_klass, *args)
    end

    # 根据服务名称获取服务实例
    def get_service_by_name(service_name, *args)
      # 将服务名称转换为类名
      service_class_name = service_name.to_s.camelize

      # 如果名称不包含 "Service"，添加它
      service_class_name += 'Service' unless service_class_name.end_with?('Service')

      # 获取服务实例
      get_service(service_class_name, *args)
    end

    # 获取工单处理服务
    def get_work_order_service(work_order, current_admin_user = Current.admin_user)
      # 根据工单类型获取对应的服务
      service_class = case work_order
                      when AuditWorkOrder
                        AuditWorkOrderService
                      when CommunicationWorkOrder
                        CommunicationWorkOrderService
                      when ExpressReceiptWorkOrder
                        ExpressReceiptWorkOrderService
                      else
                        raise ArgumentError, "不支持的工单类型: #{work_order.class.name}"
                      end

      # 实例化服务
      instantiate_service(service_class, work_order, current_admin_user)
    end

    # 便捷方法：获取报销单导入服务
    def reimbursement_import_service(file, current_admin_user = Current.admin_user)
      get_service(ReimbursementImportService, file, current_admin_user)
    end

    # 便捷方法：获取快递收单导入服务
    def express_receipt_import_service(file, current_admin_user = Current.admin_user)
      get_service(ExpressReceiptImportService, file, current_admin_user)
    end

    # 便捷方法：获取费用明细导入服务
    def fee_detail_import_service(file, current_admin_user = Current.admin_user)
      get_service(FeeDetailImportService, file, current_admin_user)
    end

    # 便捷方法：获取操作历史导入服务
    def operation_history_import_service(file, current_admin_user = Current.admin_user)
      get_service(OperationHistoryImportService, file, current_admin_user)
    end

    # 便捷方法：获取审核工单服务
    def audit_work_order_service(audit_work_order, current_admin_user = Current.admin_user)
      get_service(AuditWorkOrderService, audit_work_order, current_admin_user)
    end

    # 便捷方法：获取沟通工单服务
    def communication_work_order_service(communication_work_order, current_admin_user = Current.admin_user)
      get_service(CommunicationWorkOrderService, communication_work_order, current_admin_user)
    end

    # 便捷方法：获取费用明细验证服务
    def fee_detail_verification_service(current_admin_user = Current.admin_user)
      get_service(FeeDetailVerificationService, current_admin_user)
    end

    private

    # 检查服务类是否存在
    def service_class_exists?(service_class)
      return true if service_class.is_a?(Class)

      begin
        service_class.to_s.constantize
        true
      rescue NameError
        false
      end
    end

    # 实例化服务
    def instantiate_service(service_klass, *args)
      # 如果第一个参数是工单，并且没有提供当前用户，使用 Current.admin_user
      if args.first.is_a?(WorkOrder) && args.length == 1
        service_klass.new(args.first, Current.admin_user)
      else
        service_klass.new(*args)
      end
    end
  end
end
