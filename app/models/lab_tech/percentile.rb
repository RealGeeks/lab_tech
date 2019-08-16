module LabTech
  module Percentile
    extend self

    MIN_PERCENTILE = 0
    MAX_PERCENTILE = 100

    def call(pct, list)
      # Make sure this list is actually sorted
      unless sorted?(list)
        fail "Sorry, this isn't sorted: #{list.inspect}"
      end

      msg = "Please pass an integer between #{MIN_PERCENTILE} and #{MAX_PERCENTILE}, not #{pct.inspect}"
      raise ArgumentError, msg unless pct.kind_of?(Integer)
      raise ArgumentError, msg unless (MIN_PERCENTILE..MAX_PERCENTILE).cover?(pct)

      return list.first if pct == MIN_PERCENTILE # Avoid the need for a bounds check later
      return list.last  if pct == MAX_PERCENTILE # By definition, I guess

      i = ( 0.01 * pct * list.length ).ceil - 1 # Don't ask me why this works
      list[ i ]
    end

    private

    def sorted?(list)
      ret_val = true
      list.each_cons(2) do |a,b|
        if a <= b
          next
        else
          ret_val = false
          break
        end
      end
      ret_val
    end

  end
end
