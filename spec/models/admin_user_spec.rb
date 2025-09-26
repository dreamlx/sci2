require 'rails_helper'

RSpec.describe AdminUser, type: :model do
  describe '.find_by_name_substring' do
    let!(:admin_user1) { create(:admin_user, name: 'John Doe') }
    let!(:admin_user2) { create(:admin_user, name: 'Jane Smith') }
    let!(:admin_user3) { create(:admin_user, name: 'Bob Johnson') }

    context 'when the string contains the exact admin user name' do
      it 'returns the admin user' do
        result = AdminUser.find_by_name_substring('John Doe')
        expect(result).to eq(admin_user1)
      end
    end

    context 'when the string contains the admin user name as a substring' do
      it 'returns the admin user when name is embedded in larger string' do
        result = AdminUser.find_by_name_substring('Dr. John Doe Jr.')
        expect(result).to eq(admin_user1)
      end

      it 'returns the admin user when name is in the middle' do
        result = AdminUser.find_by_name_substring('Bob Johnson Esq.')
        expect(result).to eq(admin_user3)
      end
    end

    context 'when name_substring does not match any user' do
      it 'returns nil' do
        result = AdminUser.find_by_name_substring('Nonexistent User')
        expect(result).to be_nil
      end
    end

    context 'when name_substring is blank' do
      it 'returns nil' do
        result = AdminUser.find_by_name_substring('')
        expect(result).to be_nil
      end

      it 'returns nil when nil' do
        result = AdminUser.find_by_name_substring(nil)
        expect(result).to be_nil
      end
    end

    context 'when multiple users match' do
      let!(:admin_user4) { create(:admin_user, name: 'Jane') }

      it 'returns the first matching user (by database order)' do
        result = AdminUser.find_by_name_substring('Jane Smith and Jane Doe')
        expect([admin_user2, admin_user4]).to include(result)
      end
    end
  end
end
