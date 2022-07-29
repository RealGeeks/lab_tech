module LabTech
  class Engine < ::Rails::Engine
    isolate_namespace LabTech
    config.generators.api_only = true

    config.after_initialize do
      # NOTE: this list also exists in the README; please try to keep them in sync.
      required_serializable_classes = [
        ActiveSupport::Duration,
        ActiveSupport::TimeWithZone,
        ActiveSupport::TimeZone,
        Symbol,
        Time,
      ]

      missing_classes = required_serializable_classes - Rails.configuration.active_record.yaml_column_permitted_classes

      if missing_classes.any?
        puts <<~EOF.red

          Please add the following classes to your
          Rails.configuration.active_record.yaml_column_permitted_classes:
          #{ missing_classes.map { |klass| "  - #{klass}" }.join('\n') }

          Because LabTech uses ActiveRecord's `serialize` to save experimental
          results to the database, running experiments is likely to break your
          application horribly without this configuration.

        EOF
      end
    end
  end
end
