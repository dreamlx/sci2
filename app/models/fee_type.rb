class FeeType < ApplicationRecord
  # 验证
  validates :name, presence: true, uniqueness: true

  # 关联
  has_many :problem_type_fee_types, dependent: :destroy
  has_many :problem_types, through: :problem_type_fee_types
  has_many :fee_details, dependent: :nullify

  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id name created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[problem_type_fee_types problem_types fee_details]
  end
end 