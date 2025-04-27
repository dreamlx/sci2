class CommunicationRecord < ApplicationRecord
  # 关联
  belongs_to :communication_work_order

  # 验证
  validates :content, presence: true
  validates :communicator_role, presence: true
  validates :communication_work_order_id, presence: true

  # 回调
  before_create :set_recorded_at

  private

  def set_recorded_at
    self.recorded_at ||= Time.current
  end

  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id communication_work_order_id content communicator_role communicator_name communication_method recorded_at created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[communication_work_order]
  end
end