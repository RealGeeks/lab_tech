module LabTech
  class DefaultCleaner
    def self.call( value )
      new.call( value )
    end

    def call( value )
      clean( value, return_placeholders: false )
    end

    class RecordPlaceholder
      attr_reader :class_name, :id
      def initialize( record )
        @class_name = record.class.to_s
        @id         = record.id
      end

      def to_a
        [ class_name, id ]
      end

      def inspect
        "<#{class_name} ##{id}>"
      end
    end

    private

    # In the event of a Recursion Blunder, stop before we smash the stack, so we
    # can actually get a useful stack trace that doesn't overwhelm our scrollback
    # buffers
    MAX_DEPTH = 10
    def __push__
      @depth ||= 0
      @depth += 1
      fail "wtf are you even doing?" if @depth > MAX_DEPTH
    end
    def __pop__
      @depth -= 1
    end

    def clean( value, return_placeholders: )
      __push__

      case value
      when RecordPlaceholder
        clean_record_placeholder( value, return_placeholders: return_placeholders )
      when ActiveRecord::Base
        clean_record( value, return_placeholders: return_placeholders )
      when Array
        clean_array( value, return_placeholders: return_placeholders )
      else
        value
      end

    ensure
      __pop__
    end

    def clean_array( value, return_placeholders: )
      placeholders = value.map {|e| clean(e, return_placeholders: true) }
      if placeholders.all? { |e| e.kind_of?(RecordPlaceholder) } && !return_placeholders
        count_placeholders( placeholders )
      else
        placeholders.map {|e| clean(e, return_placeholders: return_placeholders) }
      end
    end

    def clean_record( value, return_placeholders: )
      placeholder = RecordPlaceholder.new( value )
      clean_record_placeholder( placeholder, return_placeholders: return_placeholders )
    end

    def clean_record_placeholder( value, return_placeholders: )
      return_placeholders \
        ? value \
        : value.to_a
    end

    def count_placeholders( placeholders )
      counts = placeholders.group_by(&:class_name).map { |class_name, summs|
        [ class_name, summs.map(&:id) ]
      }
      Hash[ counts ]
    end
  end
end
