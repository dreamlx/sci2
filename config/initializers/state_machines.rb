# config/initializers/state_machines.rb
begin
  require 'state_machines/active_record'
  # 配置 state_machines 初始化
  StateMachines::Machine.ignore_method_conflicts = true
rescue LoadError => e
  # Log the error but don't crash the application
  puts "Warning: state_machines/active_record could not be loaded: #{e.message}"
  # Define a minimal StateMachines module if it doesn't exist
  unless defined?(StateMachines)
    module StateMachines
      class Machine
        def self.ignore_method_conflicts=(value)
          # No-op
        end
      end
    end
  end
end