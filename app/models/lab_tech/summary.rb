module LabTech
  class Summary
    TAB  = " " * 4
    LINE = "-" * 80
    VAL = "█"
    DOT = "·"

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
      speedup_magnitude = @speedup_factors.minmax.map(&:to_i).map(&:abs).max.ceil
      speedup_magnitude = 25 if speedup_magnitude.zero?
      (0..100).step(5) do |n|
        s.puts TAB + speedup_summary_line(n, speedup_magnitude)
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

    def highlight_bar(bar)
      left, right = bar.split(VAL)

      left  = left         .gsub("  ", " #{DOT}")
      right = right.reverse.gsub("  ", " #{DOT}").reverse

      left + VAL + right
    end

    def humanize(n)
      width = number_helper.number_with_delimiter( @counts[:results] ).length
      "%#{width}s" % number_helper.number_with_delimiter( n )
    end

    def pad_left(s, width)
      n = [ ( width - s.length ), 0 ].max
      [ " " * n , s ].join
    end

    def normalized_bar(x, magnitude, bar_scale: 25, highlight: false)
      neg, pos = " " * bar_scale, " " * bar_scale
      normalized = ( bar_scale * ( x.abs / magnitude ) ).floor

      # Select an index that's as close to `normalized` as possible without generating IndexErrors
      # (TODO: actually understand the math involved so I don't have to chop the ends off like an infidel)
      index = [ 0, normalized ].max
      index = [ index, bar_scale - 1 ].min

      case
      when x == 0 ; mid = VAL
      when x <  0 ; mid = DOT ; neg[ index ] = VAL ; neg = neg.reverse
      when x  > 0 ; mid = DOT ; pos[ index ] = VAL
      end

      bar = "[%s%s%s]" % [ neg, mid, pos ]
      bar = highlight_bar(bar) if highlight
      bar
    end

    def number_helper
      @_number_helper ||= Object.new.tap {|o| o.send :extend, ActionView::Helpers::NumberHelper }
    end

    def rate(n)
      "%2.2f%%" % ( 100.0 * n / @counts[:results] )
    end

    def speedup_summary_line(n, speedup_magnitude)
      highlight = n == 50
      label = "%3d%%" % n

      speedup_factor = LabTech::Percentile.call(n, @speedup_factors)
      rel_speedup    = "%+.1fx" % speedup_factor
      bar            = normalized_bar( speedup_factor, speedup_magnitude, highlight: highlight)

      speedup_cue    = pad_left( rel_speedup, speedup_width )
      speedup_cue += " faster" if speedup_factor > 0

      "#{label}  #{bar}  #{speedup_cue}"
    end

    def speedup_width
      @_speedup_width ||= [
        1, # sign
        4, # digits
        1, # decimal point
        1, # digit after decimal point
      ].sum
    end

    def summarize_count(s, count_name, label = nil)
      count = @counts[count_name]
      return if count.zero?

      total = @counts[:results]
      label ||= count_name.to_s
      s.puts "%s of %s (%s) %s" % [ humanize( count ), humanize( total ), rate( count ), label ]
    end

  end
end
