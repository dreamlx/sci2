# frozen_string_literal: true

module DateParsingHelper
  # 解析日期字符串为Date对象
  # @param date_string [String, Date, DateTime, nil] 待解析的日期
  # @return [Date, nil] 解析后的日期或nil
  def parse_date(date_string)
    return nil unless date_string.present?

    begin
      if date_string.is_a?(Date) || date_string.is_a?(DateTime)
        date_string.to_date
      else
        Date.parse(date_string.to_s)
      end
    rescue ArgumentError => e
      Rails.logger.warn "Failed to parse date: #{date_string} - #{e.message}"
      nil
    end
  end

  # 解析日期时间字符串为DateTime对象
  # @param datetime_string [String, Date, DateTime, nil] 待解析的日期时间
  # @return [DateTime, nil] 解析后的日期时间或nil
  def parse_datetime(datetime_string)
    return nil unless datetime_string.present?

    begin
      if datetime_string.is_a?(Date) || datetime_string.is_a?(DateTime)
        datetime_string
      else
        DateTime.parse(datetime_string.to_s)
      end
    rescue ArgumentError => e
      Rails.logger.warn "Failed to parse datetime: #{datetime_string} - #{e.message}"
      nil
    end
  end
end
