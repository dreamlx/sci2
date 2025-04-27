FactoryBot.define do
  factory :operation_history do
    document_number { "INV#{rand(1000..9999)}" }
    operation_type { %w[create update delete process complete].sample }
    operation_time { Time.current }
    operator { "admin@example.com" }
    notes { "Operation performed" }
  end
end