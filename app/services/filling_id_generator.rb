# app/services/filling_id_generator.rb
class FillingIdGenerator
  def self.generate(received_at)
    time = received_at || Time.current
    year_month = time.strftime('%Y%m')
    sequence = next_sequence(year_month)
    "#{year_month}#{sequence.to_s.rjust(4, '0')}"
  end
  
  private
  
  def self.next_sequence(year_month)
    # 查询当月最大流水号并+1
    # 使用Arel来处理SQL注入问题
    max_sequence = ExpressReceiptWorkOrder
      .where("filling_id LIKE ?", "#{year_month}%")
      .maximum(Arel.sql("CAST(SUBSTRING(filling_id, 7, 4) AS INTEGER)")) || 0
    max_sequence + 1
  end
end