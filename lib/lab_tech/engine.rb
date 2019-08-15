module LabTech
  class Engine < ::Rails::Engine
    isolate_namespace LabTech
    config.generators.api_only = true
  end
end
