    # app/models/work_order_fee_detail.rb
    class WorkOrderFeeDetail < ApplicationRecord
        belongs_to :fee_detail
        belongs_to :work_order, polymorphic: true
  
        # 校验确保唯一性，防止通过模型层面创建重复记录
        validates :fee_detail_id, uniqueness: { scope: [:work_order_id, :work_order_type], message: "已经与此工单关联" }
        validates :fee_detail_id, presence: true
        validates :work_order_id, presence: true
        validates :work_order_type, presence: true
        
        # 添加按工单类型筛选的scope
        scope :by_work_order_type, ->(type) { where(work_order_type: type) }
      end