module LabTech
class Summary

  class SpeedupLine
    VAL = "█"
    DOT = "·"

    attr_reader :n, :speedup_factors

    def initialize(n, speedup_factors)
      @n               = n
      @speedup_factors = speedup_factors
    end

    def to_s
      highlight = ( n == 50 ) # Only 'highlight' (add dots to) the median line
      label = "%3d%%" % n

      speedup_factor = LabTech::Percentile.call(n, @speedup_factors)
      rel_speedup    = "%+.1fx" % speedup_factor
      bar            = normalized_bar( speedup_factor, speedup_magnitude, highlight: highlight)

      speedup_cue  = pad_left( rel_speedup, speedup_width )
      speedup_cue += " faster" if speedup_factor > 0

      "#{label}  #{bar}  #{speedup_cue}"
    end

    private

    def highlight_bar(bar)
      left, right = bar.split(VAL)

      left  = left         .gsub("  ", " #{DOT}")
      right = right.reverse.gsub("  ", " #{DOT}").reverse

      left + VAL + right
    end

    def normalized_bar(x, magnitude, bar_scale: 25, highlight: false)
      neg, pos = " " * bar_scale, " " * bar_scale
      normalized = ( bar_scale * ( x.abs / magnitude ) ).floor

      # Select an index that's as close to `normalized` as possible without generating IndexErrors
      # (TODO: actually understand the math involved so I don't have to chop the ends off like an infidel)
      index = normalized.clamp( 0, bar_scale - 1 )

      case
      when x == 0 ; mid = VAL
      when x <  0 ; mid = DOT ; neg[ index ] = VAL ; neg = neg.reverse
      when x  > 0 ; mid = DOT ; pos[ index ] = VAL
      end

      bar = "[%s%s%s]" % [ neg, mid, pos ]
      bar = highlight_bar(bar) if highlight
      bar
    end

    def pad_left(s, width)
      n = [ ( width - s.length ), 0 ].max
      [ " " * n , s ].join
    end

    def speedup_magnitude
      @_speedup_magnitude ||=
        begin
          mag = @speedup_factors.minmax.map(&:to_i).map(&:abs).max.ceil
          mag = 25 if mag.zero?
          mag
        end
    end

    def speedup_width
      @_speedup_width ||= [
        1, # sign
        4, # digits
        1, # decimal point
        1, # digit after decimal point
      ].sum
    end
  end

end
end
