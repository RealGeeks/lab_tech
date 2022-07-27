module LabTech
  class Engine < ::Rails::Engine
    isolate_namespace LabTech
    config.generators.api_only = true

    config.after_initialize do
      required_serializable_classes = [
        ActiveSupport::Duration,
        ActiveSupport::TimeWithZone,
        ActiveSupport::TimeZone,
        Time,  
      ]
      
      missing_classes = required_serializable_classes - Rails.configuration.active_record.yaml_column_permitted_classes

      if missing_classes.any?
        puts "Please add #{missing_classes.join(', ')} to your Rails.configuration.active_record.yaml_column_permitted_classes.".red      
        puts "LabTech will break your application horribly unless you do.".red      
      end
    end
  end
end
