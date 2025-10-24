FactoryBot.define do
  factory :reimbursement_assignment do
    association :reimbursement
    association :assignee, factory: :admin_user
    association :assigner, factory: :admin_user
    is_active { true }
    notes { '测试分配' }
  end
end
