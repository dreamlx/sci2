module ActiveAdmin
  module Views
    class CustomScope < ActiveAdmin::Component
      builder_method :custom_scope

      def build(scope, options = {})
        super(options)
        @scope = scope
        text_node scope_label
      end

      private

      def scope_label
        if @scope.name.is_a?(Symbol)
          I18n.t("active_admin.scopes.#{@scope.name}")
        else
          @scope.name
        end
      end
    end
  end
end
