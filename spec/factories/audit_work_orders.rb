FactoryBot.define do
  factory :audit_work_order do
    association :reimbursement
    association :express_receipt_work_order, factory: :express_receipt_work_order, strategy: :build
    status { 'pending' }
    created_by { 1 }

    trait :processing do
      status { 'processing' }
    end

    trait :auditing do
      status { 'auditing' }
    end

    trait :approved do
      status { 'approved' }
      audit_result { 'approved' }
      audit_date { Time.current }
    end

    trait :rejected do
      status { 'rejected' }
      audit_result { 'rejected' }
      audit_date { Time.current }
    end

    trait :needs_communication do
      status { 'needs_communication' }
    end

    trait :completed do
      status { 'completed' }
      audit_result { 'approved' }
      audit_date { Time.current }
    end

    trait :with_fee_details do
      transient do
        fee_details_count { 3 }
      end

      after(:create) do |audit_work_order, evaluator|
        create_list(:fee_detail, evaluator.fee_details_count, document_number: audit_work_order.reimbursement.invoice_number).each do |fee_detail|
          audit_work_order.select_fee_detail(fee_detail)
        end
      end
    end
  end
end