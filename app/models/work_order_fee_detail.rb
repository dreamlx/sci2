    # app/models/work_order_fee_detail.rb
    class WorkOrderFeeDetail < ApplicationRecord
        belongs_to :fee_detail
        belongs_to :work_order, polymorphic: true
  
        # 校验确保唯一性，防止通过模型层面创建重复记录
        validates :fee_detail_id, uniqueness: { scope: [:work_order_id, :work_order_type], message: "is already associated with this work order" }
      end