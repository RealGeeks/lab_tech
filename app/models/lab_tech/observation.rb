module LabTech
  class Observation < ApplicationRecord
    self.table_name = "lab_tech_observations"

    belongs_to :result, class_name: "LabTech::Result", foreign_key: :result_id, optional: true

    scope :timed_out,   -> {     where(exception_class: 'Timeout::Error') }
    scope :other_error, -> { where.not(exception_class: 'Timeout::Error') }

    serialize :value

    def raised_error?
      exception_values = [ exception_class, exception_message, exception_backtrace ]
      exception_values.any?( &:present? )
    end

    def record_a_science(scientist_observation)
      unless scientist_observation.kind_of?( Scientist::Observation )
        raise ArgumentError, "expected a Scientist::Observation but got #{scientist_observation.class}"
      end

      self.name     = scientist_observation.name
      self.duration = scientist_observation.duration

      self.value = scientist_observation.cleaned_value
      record_errors scientist_observation.exception
    end

    def timed_out?
      exception_class == "Timeout::Error"
    end

    private

    def record_errors(exception)
      return if exception.nil?

      self.exception_class     = exception.class
      self.exception_message   = exception.message
      self.exception_backtrace = exception.backtrace
    end
  end
end
