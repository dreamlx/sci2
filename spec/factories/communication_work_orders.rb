FactoryBot.define do
  factory :communication_work_order do
    association :reimbursement
    association :audit_work_order, factory: :audit_work_order, strategy: :build
    status { 'open' }
    communication_method { 'email' }
    initiator_role { 'auditor' }
    created_by { 1 }

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :resolved do
      status { 'resolved' }
      resolution_summary { '问题已解决' }
    end

    trait :unresolved do
      status { 'unresolved' }
      resolution_summary { '无法解决' }
    end

    trait :closed do
      status { 'closed' }
    end

    trait :with_records do
      transient do
        records_count { 2 }
      end

      after(:create) do |work_order, evaluator|
        create_list(:communication_record, evaluator.records_count, communication_work_order: work_order)
      end
    end

    trait :with_fee_details do
      transient do
        fee_details_count { 2 }
      end

      after(:create) do |work_order, evaluator|
        create_list(:fee_detail, evaluator.fee_details_count, document_number: work_order.reimbursement.invoice_number).each do |fee_detail|
          work_order.select_fee_detail(fee_detail)
        end
      end
    end
  end
end