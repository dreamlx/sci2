class DocumentCategory < ApplicationRecord
  has_many :problem_types, dependent: :nullify # Or :restrict_with_error if a category must not be deleted if it has problem types

  validates :name, presence: true, uniqueness: true
  # validates :active, inclusion: { in: [true, false] } # This is handled by `null: false` in DB
  # Keywords are stored as a comma-separated string
  validates :keywords, presence: true, if: -> { name != '其他类别' } # Allow '其他类别' to have empty keywords

  scope :active, -> { where(active: true) }

  # For SQLite, keywords are stored as a comma-separated string.
  # This method splits them into an array.
  def keyword_list
    keywords.split(',').map(&:strip).reject(&:blank?)
  end

  # Checks if any of its keywords are present in the given text.
  def matches_text?(text_to_check)
    return false if text_to_check.blank?
    downcased_text = text_to_check.downcase
    keyword_list.any? { |kw| downcased_text.include?(kw.downcase) }
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id name keywords active created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    ["problem_types"]
  end

  # Class method to find the best matching category for a given document name
  # Returns the "其他类别" category if no specific match is found.
  def self.find_for_document_name(document_name)
    return find_other_category if document_name.blank?

    best_match = nil
    highest_priority_match = -1 # Could be based on number of keywords matched or a dedicated priority field

    active.find_each do |category|
      next if category.name == '其他类别' # Skip the general 'Other' category in initial matching
      if category.matches_text?(document_name)
        # Simple first match for now, can be extended for priority
        # For example, a category matching more keywords, or a specific keyword, could be prioritized.
        # Or, if categories have a `priority` field, use that.
        # For now, first active match wins.
        return category
      end
    end
    
    # Fallback to "其他类别"
    find_other_category
  end

  def self.find_other_category
    find_by(name: '其他类别') || create_other_category_if_not_exists # Ensure '其他类别' always exists
  end

  private

  def self.create_other_category_if_not_exists
    # This is a fallback, ideally '其他类别' is seeded.
    find_or_create_by(name: '其他类别') do |cat|
      cat.keywords = ''
      cat.active = true
    end
  end
end
