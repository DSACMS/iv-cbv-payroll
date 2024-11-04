module ApiResponseLocalizer
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def localize_methods(*method_names)
      method_names.each do |method_name|
        alias_method "original_#{method_name}", method_name

        # Define the new method with localization
        define_method(method_name) do |*args, **kwargs|
          response = send("original_#{method_name}", *args, **kwargs)
          localized_response = localize_response(response)
          localized_response
        end
      end
    end
  end

  private

  def localize_response(response)
    return response if I18n.locale == :en

    case response
    when Hash
      response.transform_values { |v| localize_response(v) }
    when Array
      response.map { |item| localize_response(item) }
    when String
      # Convert string to snake_case and downcase
      lookup_key = response.downcase.gsub("-", "_")
      I18n.t(lookup_key, scope: i18n_scope, default: response)
    else
      response
    end
  end

  # set the I18n scope based on the class name
  def i18n_scope
    "#{self.class.name.underscore.remove('_service')}"
  end
end
