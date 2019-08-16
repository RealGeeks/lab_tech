module LabTech
  class Speedup
    attr_reader :baseline, :comparison, :time, :factor

    def self.compute_time_delta(baseline, comparison)
      return nil if baseline.nil?
      return nil if comparison.nil?

      baseline.to_f - comparison.to_f
    end

    def self.compute_factor(baseline, comparison)
      # Timing data should never be zero
      return nil if [ baseline, comparison ].any? { |e| e.to_f.zero? }

      time = compute_time_delta(baseline, comparison)
      return nil if time.nil?

      case
      when time > 0   ; +1 * baseline   / comparison
      when time.zero? ;  0
      when time < 0   ; -1 * comparison / baseline
      end
    end

    def initialize(baseline: nil, comparison: nil, time: nil, factor: nil)
      @baseline   = baseline   &.to_f
      @comparison = comparison &.to_f
      @time       = time       &.to_f || compute_time_delta
      @factor     = factor     &.to_f || compute_factor
    end

    include Comparable
    def <=>(other)
      return nil unless other.kind_of?(self.class)
      return nil   if self .factor.nil?
      return other if other.factor.nil?

      self.factor <=> other.factor
    end

    def valid?
      return false if time.nil?
      return false if factor.nil?

      expected_time_delta = compute_time_delta
      expected_factor     = compute_factor

      return false if expected_time_delta && ( time   != expected_time_delta )
      return false if expected_factor     && ( factor != expected_factor     )

      true
    end

    private

    def compute_time_delta
      self.class.compute_time_delta(baseline, comparison)
    end

    def compute_factor
      self.class.compute_factor(baseline, comparison)
    end
  end
end
