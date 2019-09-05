module LabTech
  class Summary
    TAB  = " " * 4
    LINE = "-" * 80

    def initialize(experiment)
      @experiment = experiment
    end

    def to_s
      if experiment.results.count.zero?
        return [ LINE, "No results for experiment #{@experiment.name.inspect}", LINE ].join("\n")
      end

      fetch_data

      s = StringIO.new
      s.puts LINE, "Experiment: #{@experiment.name}", LINE

      add_time_span_to s
      add_counts_to s

      if @time_deltas.any?
        add_time_deltas_to s
        add_speedup_chart_to s
      end

      s.puts LINE
      return s.string
    end

    private

    attr_reader :experiment

    def add_counts_to(s)
      s.puts
      summarize_count( s, :correct )
      summarize_count( s, :mismatched )
      summarize_count( s, :timeout, "timed out" )
      summarize_count( s, :errored, "raised errors" )
    end

    def add_speedup_chart_to(s)
      s.puts
      s.puts "Speedups (by percentiles):"
      (0..100).step(5) do |n|
        line = SpeedupLine.new(n, @speedup_factors)
        s.puts TAB + line.to_s
      end
    end

    def add_time_deltas_to(s)
      percentile = ->(n) { "%+.3fs" % LabTech::Percentile.call(n, @time_deltas) }
      s.puts
      s << "Median time delta: #{percentile.(50)}"
      s << "  "
      s << "(90% of observations between #{percentile.(5)} and #{percentile.(95)})"
      s.puts
    end

    def add_time_span_to(s)
      t0, t1 = @earliest_result, @latest_result
      s.puts "Earliest results: #{ t0.iso8601 }"
      s.puts "Latest result:    #{ t1.iso8601 } (%s)" \
        % date_helper.distance_of_time_in_words(t0, t1)
    end

    def date_helper
      @_date_helper ||= Object.new.tap do |o|
        o.extend ActionView::Helpers::DateHelper
      end
    end

    def fetch_data
      # Grab all aggregate operations counts/lists inside a transaction
      # so all the counts are consistent
      @experiment.transaction do
        scope = experiment.results

        @earliest_result = scope.minimum(:created_at)
        @latest_result   = scope.maximum(:created_at)

        @counts = {
          results:    scope.count,
          correct:    scope.correct.count,
          mismatched: scope.mismatched.count,
          timeout:    scope.timed_out.count,
          errored:    scope.other_error.count,
        }

        speedups = experiment.results.correct.pluck(:time_delta, :speedup_factor).map { |time, factor|
          LabTech::Speedup.new(time: time, factor: factor)
        }
        @time_deltas     = speedups.map(&:time).compact.sort
        @speedup_factors = speedups.map(&:factor).compact.sort
      end
    end

    def summarize_count(s, count_name, label = nil)
      n     = @counts[count_name]
      total = @counts[:results]
      count = Count.new(count_name, n, total, label)
      return if count.zero?
      s.puts count.to_s
    end

  end
end
