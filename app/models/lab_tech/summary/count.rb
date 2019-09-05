module LabTech
class Summary

  class Count
    attr_reader :name, :n, :total, :label

    def initialize(name, n, total, label = nil)
      @name  = name
      @n     = n
      @total = total
      @label = label || name.to_s
    end

    def zero?
      n.zero?
    end

    def to_s
      "%s of %s (%s) %s" % [
        humanize( n ),
        humanize( total ),
        rate( n ),
        label
      ]
    end

    private

    def humanize(n)
      width = number_helper.number_with_delimiter( n ).length
      "%#{width}s" % number_helper.number_with_delimiter( n )
    end

    def number_helper
      @_number_helper ||= Object.new.tap {|o| o.send :extend, ActionView::Helpers::NumberHelper }
    end

    def rate(n)
      "%2.2f%%" % ( 100.0 * n / total )
    end
  end

end
end
