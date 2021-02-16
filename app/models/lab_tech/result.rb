module LabTech
  class Result < ApplicationRecord
    self.table_name = "lab_tech_results"

    belongs_to :experiment, class_name: "LabTech::Experiment"
    has_many :observations, class_name: "LabTech::Observation", dependent: :destroy
    has_one :control,     ->() {     where(name: 'control') }, class_name: "LabTech::Observation"
    has_many :candidates, ->() { where.not(name: 'control') }, class_name: "LabTech::Observation"
    serialize :context

    # NOTE: I don't think this accounts for the possibility that both the
    # control and candidate might raise, and if so, whether raising the same
    # exception should be considered equivalent.  (Unless I already thought of this?)
    scope :correct,     -> { where( equivalent: true,  raised_error: false ) }
    scope :mismatched,  -> { where( equivalent: false, raised_error: false ) }
    scope :errored,     -> { where( equivalent: false, raised_error: true ) }
    scope :timed_out,   -> { errored.joins(:candidates).merge(Observation.timed_out) }
    scope :other_error, -> { errored.joins(:candidates).merge(Observation.other_error) }

    after_create :increment_experiment_counters


    ##### CLASS METHODS #####

    # ugh: https://eregon.me/blog/2021/02/13/correct-delegation-in-ruby-2-27-3.html
    class << self
      def record_a_science( experiment, scientist_result, *args )
        create!(experiment: experiment) do |result|
          result.record_a_science scientist_result, *args
        end
      end
      ruby2_keywords :record_a_science if respond_to?(:ruby2_keywords, true)
    end



    ##### INSTANCE METHODS #####

    # Having multiple candidates is annoying; I've mistyped this one a lot
    def candidate
      candidates.first
    end

    DEFAULT_COMPARISON = ->(control, candidate) {
      [ control, candidate ].map { |obs|
        "    %20s # => %s" % [ obs.name, obs.value.inspect ]
      }
    }
    def compare_observations(io: $stdout, &block)
      block ||= DEFAULT_COMPARISON
      candidates.each do |candidate|
        io.puts block.( control, candidate )
      end
      return nil
    end

    def record_a_science(scientist_result, diff_with: nil)
      unless scientist_result.kind_of?( Scientist::Result )
        raise ArgumentError, "expected a Scientist::Result but got #{scientist_result.class}"
      end

      self.context = scientist_result.context

      record_observation scientist_result.control
      scientist_result.candidates.each do |candidate|
        diff = nil
        if diff_with
          # Pass values to the diff block, not the observations themselves
          cont = scientist_result.control.value
          cand = candidate.value
          diff = diff_with&.call(cont, cand)
        end

        record_observation candidate, diff: diff
      end

      record_simple_stats scientist_result
    end

    def speedup
      return nil unless candidates.count == 1

      LabTech::Speedup.new(
        baseline:   control.duration,
        comparison: candidate.duration,
        time:       time_delta,
        factor:     speedup_factor,
      )
    end

    def timed_out?
      candidates.any?(&:timed_out?)
    end

    private

    def increment_experiment_counters
      increment = ->(count) {
        Experiment.increment_counter count, self.experiment_id
      }
      case
      when equivalent ; increment.( :equivalent_count )
      when timed_out? ; increment.( :timed_out_count )
      else            ; increment.( :other_error_count )
      end
    end

    def record_observation(scientist_observation, attrs = {})
      self.observations.build do |observation|
        observation.assign_attributes attrs if attrs.present?
        observation.record_a_science scientist_observation
      end
    end

    def record_simple_stats(scientist_result)
      cont, cands = scientist_result.control, scientist_result.candidates

      self.equivalent = cands.all? { |cand| cand.equivalent_to?(cont, &experiment.comparator) }

      raised = ->(scientist_observation) { scientist_observation.exception.present? }
      self.raised_error = !raised.(cont) && cands.any?(&raised)

      # Time delta makes no sense if you're running more than one candidate at a time
      if cands.length == 1
        self.control_duration   = cont       .duration
        self.candidate_duration = cands.first.duration

        x = LabTech::Speedup.new(
          baseline:   control_duration,
          comparison: candidate_duration,
        )
        self.time_delta     = x.time
        self.speedup_factor = x.factor
      end
    end
  end
end
