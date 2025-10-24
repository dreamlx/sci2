# Patch for ActiveAdmin::Views::Scopes to fix the undefined method 'collection_before_scope' error
ActiveAdmin::Views::Scopes.class_eval do
  def collection_before_scope
    @collection_before_scope ||= collection
  end
end
