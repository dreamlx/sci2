# app/helpers/admin/work_order_operations_helper.rb
module Admin
  module WorkOrderOperationsHelper
    def state_diff(previous_state, current_state)
      return nil if previous_state.blank? || current_state.blank?
      
      begin
        prev_hash = JSON.parse(previous_state)
        curr_hash = JSON.parse(current_state)
        
        # Get all keys from both hashes
        all_keys = (prev_hash.keys + curr_hash.keys).uniq
        
        # Build HTML diff
        html = '<div class="diff">'
        
        all_keys.each do |key|
          if !prev_hash.key?(key)
            # Key only in current state (added)
            html += "<div class='ins'>+ #{key}: #{curr_hash[key].inspect}</div>"
          elsif !curr_hash.key?(key)
            # Key only in previous state (removed)
            html += "<div class='del'>- #{key}: #{prev_hash[key].inspect}</div>"
          elsif prev_hash[key] != curr_hash[key]
            # Key in both but value changed
            html += "<div class='del'>- #{key}: #{prev_hash[key].inspect}</div>"
            html += "<div class='ins'>+ #{key}: #{curr_hash[key].inspect}</div>"
          end
        end
        
        html += '</div>'
        html.html_safe
      rescue JSON::ParserError
        "无法解析JSON数据"
      end
    end
  end
end