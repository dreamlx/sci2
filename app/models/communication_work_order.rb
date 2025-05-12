# app/models/communication_work_order.rb
# frozen_string_literal: true

class CommunicationWorkOrder < WorkOrder
  # 关联
  has_many :communication_records, dependent: :destroy

  # 状态机
  state_machine :status, initial: :pending do
    event :start_processing do
      transition pending: :processing
    end

    event :complete do
      transition processing: :completed
    end

    event :reject do
      transition [:pending, :processing] => :rejected
    end

    event :reset do
      transition [:completed, :rejected] => :pending
    end
  end

  # ActiveAdmin 支持
  def self.ransackable_attributes(auth_object = nil)
    super + []
  end

  def self.ransackable_associations(auth_object = nil)
    super + []
  end

  private

  def processing_opinion_pass_or_cannot_pass?
    processing_opinion.in?(['可以通过', '无法通过'])
  end
end