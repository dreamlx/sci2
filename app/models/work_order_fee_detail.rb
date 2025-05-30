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
  
  # 添加按费用明细ID筛选的scope
  scope :by_fee_detail, ->(fee_detail_id) { where(fee_detail_id: fee_detail_id) }
  
  # 添加按工单ID筛选的scope
  scope :by_work_order, ->(work_order_id, work_order_type) {
    where(work_order_id: work_order_id, work_order_type: work_order_type)
  }
  
  # 回调：创建或更新关联后，更新费用明细的验证状态
  after_commit :update_fee_detail_status, on: [:create, :update]
  
  # 回调：删除关联后，更新费用明细的验证状态
  after_commit :update_fee_detail_status, on: :destroy
  
  private
  
  # 更新费用明细的验证状态
  # 这里使用 FeeDetailStatusService 来实现"最新工单决定"原则
  def update_fee_detail_status
    # 使用 FeeDetailStatusService 更新费用明细状态
    # 这将根据最新关联的工单状态来决定费用明细的验证状态
    service = FeeDetailStatusService.new([fee_detail_id])
    service.update_status
  end
end