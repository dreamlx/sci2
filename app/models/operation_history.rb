class OperationHistory < ApplicationRecord
  validates :document_number, presence: true
  validates :operation_type, presence: true
  validates :operation_time, presence: true
  validates :operator, presence: true

  OPERATION_TYPES = {
    create: 'create',
    update: 'update',
    delete: 'delete',
    process: 'process',
    complete: 'complete'
  }.freeze

  def self.operation_types
    OPERATION_TYPES
  end
end