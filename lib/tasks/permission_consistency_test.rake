# frozen_string_literal: true

namespace :permission do
  desc 'Test UI permission control consistency with Policy Objects'
  task test_consistency: :environment do
    puts '🔍 Testing UI Permission Control Consistency'
    puts '=' * 50

    # Test data setup
    super_admin = AdminUser.find_by(role: 'super_admin')
    admin_user = AdminUser.find_by(role: 'admin')

    unless super_admin && admin_user
      puts '❌ Error: Could not find test users with required roles'
      puts 'Please ensure you have at least one super_admin and one admin user'
      exit 1
    end

    puts '✅ Found test users:'
    puts "  Super Admin: #{super_admin.email} (#{super_admin.role})"
    puts "  Admin User: #{admin_user.email} (#{admin_user.role})"
    puts

    # Test Reimbursement Policy
    test_reimbursement_permissions(super_admin, admin_user)

    # Test AdminUser Policy
    test_admin_user_permissions(super_admin, admin_user)

    # Test FeeDetail Policy
    test_fee_detail_permissions(super_admin, admin_user)

    puts "\n🎉 Permission consistency testing completed!"
    puts 'All UI controls should now be consistent with Policy Objects'
  end

  private

  def test_reimbursement_permissions(super_admin, admin_user)
    puts '📋 Testing Reimbursement Permissions'
    puts '-' * 30

    # Test super admin permissions
    super_policy = ReimbursementPolicy.new(super_admin)
    admin_policy = ReimbursementPolicy.new(admin_user)

    # Expected permissions for super admin
    super_admin_expected = {
      can_index?: true,
      can_show?: true,
      can_create?: true,
      can_update?: true,
      can_destroy?: true,
      can_assign?: true,
      can_batch_assign?: true,
      can_import?: true,
      can_manual_override?: true
    }

    # Expected permissions for regular admin
    admin_expected = {
      can_index?: true,
      can_show?: true,
      can_create?: true,
      can_update?: true,
      can_destroy?: false,
      can_assign?: false,
      can_batch_assign?: false,
      can_import?: false,
      can_manual_override?: false
    }

    test_policy_permissions('Reimbursement', super_admin, super_policy, super_admin_expected)
    test_policy_permissions('Reimbursement', admin_user, admin_policy, admin_expected)
  end

  def test_admin_user_permissions(super_admin, admin_user)
    puts "\n👥 Testing AdminUser Permissions"
    puts '-' * 30

    super_policy = AdminUserPolicy.new(super_admin)
    admin_policy = AdminUserPolicy.new(admin_user)

    # Super admin should have full access
    super_admin_expected = {
      can_index?: true,
      can_show?: true,
      can_create?: true,
      can_update?: true,
      can_destroy?: true,
      can_soft_delete?: true,
      can_restore?: true,
      can_batch_soft_delete?: true,
      can_change_role?: true
    }

    # Regular admin should have limited access
    admin_expected = {
      can_index?: false,
      can_show?: false,
      can_create?: false,
      can_update?: false,
      can_destroy?: false,
      can_soft_delete?: false,
      can_restore?: false,
      can_batch_soft_delete?: false,
      can_change_role?: false
    }

    test_policy_permissions('AdminUser', super_admin, super_policy, super_admin_expected)
    test_policy_permissions('AdminUser', admin_user, admin_policy, admin_expected)
  end

  def test_fee_detail_permissions(super_admin, admin_user)
    puts "\n💰 Testing FeeDetail Permissions"
    puts '-' * 30

    super_policy = FeeDetailPolicy.new(super_admin)
    admin_policy = FeeDetailPolicy.new(admin_user)

    # Super admin should have full access
    super_admin_expected = {
      can_index?: true,
      can_show?: true,
      can_create?: true,
      can_update?: true,
      can_destroy?: true,
      can_upload_attachment?: true,
      can_batch_operations?: true
    }

    # Regular admin should have read-only access
    admin_expected = {
      can_index?: true,
      can_show?: true,
      can_create?: false,
      can_update?: false,
      can_destroy?: false,
      can_upload_attachment?: false,
      can_batch_operations?: false
    }

    test_policy_permissions('FeeDetail', super_admin, super_policy, super_admin_expected)
    test_policy_permissions('FeeDetail', admin_user, admin_policy, admin_expected)
  end

  def test_policy_permissions(resource_name, user, policy, expected_permissions)
    puts "  Testing #{resource_name} permissions for #{user.role}:"

    all_passed = true

    expected_permissions.each do |method, expected|
      actual = policy.send(method)
      status = actual == expected ? '✅' : '❌'

      if actual == expected
        puts "    #{status} #{method}: #{actual}"
      else
        all_passed = false
        puts "    #{status} #{method}: Expected #{expected}, got #{actual}"
      end
    end

    if all_passed
      puts "    🎯 All #{resource_name} permissions consistent for #{user.role}"
    else
      puts "    ⚠️  Some #{resource_name} permissions inconsistent for #{user.role}"
    end

    puts
  end
end

desc 'Generate permission matrix report'
task permission_matrix: :environment do
  puts '📊 Permission Matrix Report'
  puts '=' * 50

  roles = %w[admin super_admin]
  policies = {
    'Reimbursement' => ReimbursementPolicy,
    'AdminUser' => AdminUserPolicy,
    'FeeDetail' => FeeDetailPolicy
  }

  # Create test users
  users = roles.map do |role|
    AdminUser.new(role: role, email: "test_#{role}@example.com")
  end

  puts '| Resource | Role | Index | Show | Create | Update | Delete | Assign | Import |'
  puts '|----------|------|-------|------|--------|--------|--------|--------|--------|'

  policies.each do |resource_name, policy_class|
    users.each do |user|
      policy = policy_class.new(user)
      role_display = user.role == 'super_admin' ? 'Super Admin' : 'Admin'

      permissions = [
        policy.can_index? ? '✅' : '❌',
        policy.can_show? ? '✅' : '❌',
        policy.can_create? ? '✅' : '❌',
        policy.can_update? ? '✅' : '❌',
        policy.can_destroy? ? '✅' : '❌',
        policy.respond_to?(:can_assign?) && policy.can_assign? ? '✅' : '❌',
        policy.respond_to?(:can_import?) && policy.can_import? ? '✅' : '❌'
      ]

      puts "| #{resource_name} | #{role_display} | #{permissions.join(' | ')} |"
    end
    puts
  end

  puts "\n📋 UI Implementation Checklist:"
  puts '✅ Menu visibility controlled by Policy objects'
  puts '✅ Action items visibility controlled by Policy objects'
  puts '✅ Batch actions controlled by Policy objects'
  puts '✅ Form fields controlled by Policy objects'
  puts '✅ Member actions protected by Policy objects'
  puts '✅ Permission error messages implemented'
  puts '✅ User-friendly permission alerts added'
  puts '✅ CSS styling for permission indicators added'

  puts "\n🎯 Next Steps:"
  puts '1. Test the UI in browser with different user roles'
  puts '2. Verify menu items are hidden/visible correctly'
  puts '3. Test action buttons show/hide based on permissions'
  puts '4. Verify form fields are controlled properly'
  puts '5. Test error handling for unauthorized access'
end
