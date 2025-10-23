# frozen_string_literal: true

module TestMigration
  # Template generator for new architecture test patterns
  class TemplateGenerator
    PATTERNS = {
      service: {
        file_pattern: 'spec/services/%s_spec.rb',
        template_file: 'spec/support/patterns/service_template.rb'
      },
      command: {
        file_pattern: 'spec/commands/%s_spec.rb',
        template_file: 'spec/support/patterns/command_template.rb'
      },
      policy: {
        file_pattern: 'spec/policies/%s_spec.rb',
        template_file: 'spec/support/patterns/policy_template.rb'
      },
      repository: {
        file_pattern: 'spec/repositories/%s_spec.rb',
        template_file: 'spec/support/patterns/repository_template.rb'
      }
    }.freeze

    def initialize(pattern_type, class_name)
      @pattern_type = pattern_type.to_sym
      @class_name = class_name
      @pattern_config = PATTERNS[@pattern_type]

      raise ArgumentError, "Unknown pattern type: #{pattern_type}" unless @pattern_config
    end

    def generate
      template_content = build_template
      file_path = target_file_path

      ensure_directory_exists(file_path)

      {
        content: template_content,
        file_path: file_path,
        pattern_type: @pattern_type,
        class_name: @class_name
      }
    end

    def write_to_file
      result = generate

      if File.exist?(result[:file_path])
        puts "⚠️  File already exists: #{result[:file_path]}"
        return false
      end

      File.write(result[:file_path], result[:content])
      puts "✅ Generated #{result[:pattern_type]} test: #{result[:file_path]}"
      true
    end

    private

    def build_template
      case @pattern_type
      when :service
        build_service_template
      when :command
        build_command_template
      when :policy
        build_policy_template
      when :repository
        build_repository_template
      end
    end

    def build_service_template
      <<~RUBY
        # frozen_string_literal: true

        require 'rails_helper'

        RSpec.describe #{@class_name}, type: :service do
          let(:service) { described_class.new }
          let(:test_params) { {} }

          describe '#initialize' do
            it 'initializes with default values' do
              expect(service).to be_a(described_class)
            end
          end

          describe '#call' do
            context 'with valid parameters' do
              it 'returns a successful result' do
                result = service.call

                expect(result[:success]).to be(true)
                # Add more specific expectations based on your service logic
              end

              it 'performs the expected operation' do
                expect { service.call }.to change(**YOUR_MODEL**, :count).by(1)
                # Replace **YOUR_MODEL** with the actual model your service affects
              end
            end

            context 'with invalid parameters' do
              let(:invalid_params) { {} }

              it 'returns a failure result' do
                service = described_class.new(invalid_params)
                result = service.call

                expect(result[:success]).to be(false)
                expect(result[:error]).to be_present
              end

              it 'does not perform the operation' do
                service = described_class.new(invalid_params)
                expect { service.call }.not_to change(**YOUR_MODEL**, :count)
              end
            end

            context 'when unexpected error occurs' do
              before do
                allow(service).to receive(:perform_operation).and_raise(StandardError.new("Unexpected error"))
              end

              it 'returns a failure result with error message' do
                result = service.call

                expect(result[:success]).to be(false)
                expect(result[:error]).to include("Unexpected error")
              end
            end
          end

          # Add private method tests if your service has complex private logic
          describe 'private methods' do
            # Example:
            # it 'validates input correctly' do
            #   expect(service.send(:validate_input, valid_input)).to be(true)
            # end
          end
        end
      RUBY
    end

    def build_command_template
      <<~RUBY
        # frozen_string_literal: true

        require 'rails_helper'

        RSpec.describe Commands::#{@class_name}, type: :command do
          let(:admin_user) { create(:admin_user) }
          let(:command) { described_class.new }

          describe '#initialize' do
            it 'initializes with default values' do
              expect(command).to be_a(described_class)
            end

            it 'initializes with provided values' do
              cmd = described_class.new(
                # Add your command parameters here
              )
              expect(cmd).to be_a(described_class)
            end
          end

          describe '#call' do
            context 'with valid inputs' do
              let(:valid_command) do
                described_class.new(
                  # Add valid parameters here
                )
              end

              it 'executes successfully' do
                result = valid_command.call

                expect(result.success?).to be true
                expect(result.data).to be_present
                expect(result.message).to include('Successfully')
              end

              it 'creates/updates expected records' do
                expect { valid_command.call }.to change(**YOUR_MODEL**, :count).by(1)
                # Replace **YOUR_MODEL** with the actual model your command affects
              end
            end

            context 'with invalid inputs' do
              it 'fails when required parameters are missing' do
                command = described_class.new(
                  # Remove required parameters
                )

                result = command.call

                expect(result.failure?).to be true
                expect(result.errors).to be_present
              end

              it 'fails when records do not exist' do
                command = described_class.new(
                  # Use non-existent IDs
                )

                result = command.call

                expect(result.failure?).to be true
                expect(result.errors).to include("not found")
              end
            end

            context 'when service fails' do
              before do
                # Mock service failure
                # allow_any_instance_of(YourService).to receive(:perform).and_return(nil)
              end

              it 'returns failure result' do
                command = described_class.new(
                  # Add parameters here
                )

                result = command.call

                expect(result.failure?).to be true
                expect(result.errors).to include("failed")
              end
            end

            context 'when unexpected error occurs' do
              before do
                # Mock unexpected error
                # allow_any_instance_of(YourService).to receive(:perform).and_raise(StandardError.new("Database error"))
              end

              it 'returns failure result with error message' do
                command = described_class.new(
                  # Add parameters here
                )

                result = command.call

                expect(result.failure?).to be true
                expect(result.errors).to include("Unexpected error")
              end
            end
          end

          describe 'ActiveModel validations' do
            let(:command) { described_class.new }

            it 'validates required fields' do
              # Add specific validation tests
              # expect(command.valid?).to be false when field is nil
            end
          end
        end
      RUBY
    end

    def build_policy_template
      <<~RUBY
        # frozen_string_literal: true

        require 'rails_helper'

        RSpec.describe #{@class_name}, type: :policy do
          let(:super_admin) { create(:admin_user, role: 'super_admin') }
          let(:admin) { create(:admin_user, role: 'admin') }
          let(:record) { create(**YOUR_MODEL**) } # Replace **YOUR_MODEL** with actual model

          subject { described_class.new(user, record) }

          context 'when user is super admin' do
            let(:user) { super_admin }

            it 'allows all basic actions' do
              expect(subject.can_index?).to be true
              expect(subject.can_show?).to be true
              expect(subject.can_create?).to be true
              expect(subject.can_update?).to be true
              expect(subject.can_destroy?).to be true
            end

            it 'shows all UI elements' do
              expect(subject.show_action_buttons?).to eq('primary_action')
            end

            it 'returns correct role display name' do
              expect(subject.role_display_name).to eq('超级管理员')
            end
          end

          context 'when user is regular admin' do
            let(:user) { admin }

            it 'allows read-only operations' do
              expect(subject.can_index?).to be true
              expect(subject.can_show?).to be true
              expect(subject.can_create?).to be false
              expect(subject.can_update?).to be false
              expect(subject.can_destroy?).to be false
            end

            it 'hides admin-only UI elements' do
              expect(subject.show_action_buttons?).to eq('disabled_action')
            end

            it 'returns correct role display name' do
              expect(subject.role_display_name).to eq('管理员')
            end
          end

          context 'when user is nil' do
            let(:user) { nil }

            it 'disallows all operations' do
              expect(subject.can_index?).to be false
              expect(subject.can_show?).to be false
              expect(subject.can_create?).to be false
              expect(subject.can_update?).to be false
              expect(subject.can_destroy?).to be false
            end

            it 'returns unknown role display name' do
              expect(subject.role_display_name).to eq('未知角色')
            end
          end

          describe 'authorization error messages' do
            let(:user) { admin }

            it 'returns appropriate error messages' do
              expect(subject.authorization_error_message(action: :create))
                .to eq('您没有权限执行此操作，请联系超级管理员')
            end
          end

          describe 'class methods' do
            it 'provides quick permission checks' do
              expect(described_class.can_index?(super_admin)).to be true
              expect(described_class.can_show?(super_admin, record)).to be true
              expect(described_class.can_create?(super_admin)).to be true

              expect(described_class.can_create?(admin)).to be false
            end
          end
        end
      RUBY
    end

    def build_repository_template
      <<~RUBY
        # frozen_string_literal: true

        require 'rails_helper'

        RSpec.describe #{@class_name}, type: :repository do
          let!(:record1) { create(**YOUR_MODEL**, status: 'active') } # Replace **YOUR_MODEL**
          let!(:record2) { create(**YOUR_MODEL**, status: 'inactive') }
          let!(:record3) { create(**YOUR_MODEL**, status: 'active') }

          describe '.find' do
            it 'returns record when found' do
              result = described_class.find(record1.id)
              expect(result).to eq(record1)
            end

            it 'returns nil when not found' do
              result = described_class.find(99999)
              expect(result).to be_nil
            end
          end

          describe '.find_by_id' do
            it 'returns record when found' do
              result = described_class.find_by_id(record1.id)
              expect(result).to eq(record1)
            end

            it 'returns nil when not found' do
              result = described_class.find_by_id(99999)
              expect(result).to be_nil
            end
          end

          describe '.by_status' do
            it 'returns records with specified status' do
              result = described_class.by_status('active')
              expect(result.count).to eq(2)
              expect(result).to include(record1, record3)
            end
          end

          describe '.active' do
            it 'returns only active records' do
              result = described_class.active
              expect(result.count).to eq(2)
              expect(result.pluck(:status)).to all(eq('active'))
            end
          end

          describe '.status_counts' do
            it 'returns counts for each status' do
              result = described_class.status_counts
              expect(result[:active]).to eq(2)
              expect(result[:inactive]).to eq(1)
            end
          end

          describe '.created_today' do
            it 'returns records created today' do
              today_record = create(**YOUR_MODEL**, created_at: Time.current)
              result = described_class.created_today
              expect(result).to include(today_record)
            end
          end

          describe '.created_between' do
            it 'returns records created within date range' do
              start_date = 1.day.ago
              end_date = Time.current
              result = described_class.created_between(start_date, end_date)
              expect(result.count).to eq(3) # All test records were created recently
            end
          end

          describe '.search_by_name' do
            it 'returns records matching name pattern' do
              # Adjust this test based on your searchable fields
              # record_with_name = create(**YOUR_MODEL**, name: 'Test Record')
              # result = described_class.search_by_name('Test')
              # expect(result).to include(record_with_name)
            end
          end

          describe '.page' do
            it 'returns paginated results' do
              create_list(**YOUR_MODEL**, 5)
              result = described_class.page(1, 2)
              expect(result.count).to eq(2)
            end
          end

          describe '.exists?' do
            it 'returns true when record exists' do
              result = described_class.exists?(id: record1.id)
              expect(result).to be true
            end

            it 'returns false when record does not exist' do
              result = described_class.exists?(id: 99999)
              expect(result).to be false
            end
          end

          describe '.safe_find' do
            it 'returns record when found' do
              result = described_class.safe_find(record1.id)
              expect(result).to eq(record1)
            end

            it 'returns nil when not found without logging error' do
              expect(Rails.logger).not_to receive(:error)
              result = described_class.safe_find(99999)
              expect(result).to be_nil
            end

            it 'returns nil when exception occurs' do
              allow(**YOUR_MODEL**).to receive(:find).and_raise(StandardError, 'Database connection failed')
              result = described_class.safe_find(99999)
              expect(result).to be_nil
            end
          end

          describe 'method chaining' do
            it 'allows method chaining for complex queries' do
              result = described_class
                .by_status('active')
                .where('created_at >= ?', 1.day.ago)
                .order(:created_at)
                .limit(1)

              expect(result.count).to eq(1)
              expect(result.first.status).to eq('active')
            end
          end

          describe 'performance optimizations' do
            it 'uses optimized list for dashboard queries' do
              result = described_class.optimized_list
              expect(result).to respond_to(:each)
            end
          end
        end
      RUBY
    end

    def target_file_path
      sprintf(@pattern_config[:file_pattern], underscore(@class_name))
    end

    def underscore(camel_cased_word)
      camel_cased_word.to_s.gsub(/::/, '/')
                        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                        .tr('-', '_')
                        .downcase
    end

    def ensure_directory_exists(file_path)
      dir = File.dirname(file_path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end
  end
end