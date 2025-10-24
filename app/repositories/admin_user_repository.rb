# Repository for AdminUser complex queries
# Follows Repository Pattern for data access abstraction
class AdminUserRepository
  # Find admin user by checking if the given string contains the admin user's name
  # This method was moved from model to follow Repository pattern
  def self.find_by_name_substring(name_substring)
    return nil unless name_substring.present?

    AdminUser.all.find { |user| name_substring.include?(user.name) }
  end

  # Get available users (not deleted)
  def self.available_users
    AdminUser.available
  end

  # Get active users only
  def self.active_users
    AdminUser.active_users
  end

  # Get users with their current workload (number of assigned reimbursements)
  def self.users_with_workload
    AdminUser.available.left_joins(:active_assigned_reimbursements)
                .select('admin_users.*, COUNT(reimbursement_assignments.id) as workload')
                .group('admin_users.id')
  end

  # Find users by role
  def self.by_role(role)
    AdminUser.where(role: role)
  end

  # Find users who can be assigned new reimbursements
  def self.available_for_assignment
    AdminUser.active_users
  end
end