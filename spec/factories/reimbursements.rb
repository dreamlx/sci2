FactoryBot.define do
  factory :reimbursement do
    invoice_number { "INV#{rand(1000..9999)}" }
    document_name { "Document #{rand(100)}" }
    applicant { "User #{rand(100)}" }
    applicant_id { "ID#{rand(1000)}" }
    company { "Company #{rand(10)}" }
    department { "Dept #{rand(5)}" }
    amount { rand(100.0..10000.0).round(2) }
    receipt_status { 'pending' }
    reimbursement_status { 'pending' }
    receipt_date { Time.current - rand(1..30).days }
    submission_date { Time.current }
    is_electronic { [true, false].sample }
    is_complete { false }
  end
end