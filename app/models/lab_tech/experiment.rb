module LabTech
  class Experiment < ActiveRecord::Base
    self.table_name = "lab_tech_experiments"
    include ::Scientist::Experiment

    has_many :results, class_name: "LabTech::Result", dependent: :destroy
    has_many :observations, class_name: "LabTech::Observation", through: :results

    if defined?( TablePrint ) # a Very Handy Gem Indeed: http://tableprintgem.com/
      tp.set self, *[
        :id,
        { :name              => { width: 100 } },
        { :pct_enabled       => { display_name: "% Enabled" } },
        { :pct_correct       => { display_name: "% Correct" } },
        { :equivalent_count  => { display_name: "Equivalent" } },
        { :timed_out_count   => { display_name: "Timed Out" } },
        { :other_error_count => { display_name: "Other Errors" } },
        :total_count
      ]

      def pct_enabled
        format_pct( percent_enabled )
      end

      def pct_correct
        return "N/A" if total_count.zero?
        format_pct( equivalent_count, total_count )
      end

      def total_count
        equivalent_count + timed_out_count + other_error_count
      end

      private def format_pct(x, y=nil)
        x = 100.0 * x / y if y
        "%3.1f%%" % x
      end
    end



    ##### CLASS METHODS #####

    def self.named(experiment_name_or_id)
      case experiment_name_or_id
      when String  ; exp = find_or_create_by(name: experiment_name_or_id)
      when Integer ; exp = find(experiment_name_or_id)
      end
      yield exp if block_given?
      exp
    rescue ActiveRecord::RecordNotUnique
      retry
    end



    ##### INSTANCE METHODS #####

    def comparator
      @_scientist_comparator
    end

    # TODO: DRY up the io.puts structure between this and summarize_errors
    def compare_mismatches(limit: nil, io: $stdout, &block)
      mismatches = results.mismatched.includes(:observations)
      return if mismatches.empty?
      mismatches = mismatches.limit(limit) if limit

      io.puts
      io.puts "=" * 100
      io.puts "Comparing results for #{name}:"
      io.puts

      mismatches.each do |result|
        io.puts
        io.puts "-" * 100
        io.puts "Result ##{result.id}"
        result.compare_observations( io: io, &block )
        io.puts "-" * 100
      end

      io.puts
      io.puts "=" * 100
      io.puts
      nil
    end

    def disable
      update_attribute :percent_enabled, 0
    end

    def enabled?
      n = rand(100)
      fail "WTF, Ruby?" unless (0..99).cover?(n) # Paranoia? Indirect documentation? YOU DECIDE.
      n < percent_enabled
    end

    def enable(percent_enabled: 100)
      update_attribute :percent_enabled, percent_enabled
    end

    # Oh, this is a fun one: apparently Scientist::Experiment#name is
    # overriding the ActiveRecord attribute.  Override it back.
    def name         ; read_attribute  :name        ; end
    def name=(value) ; write_attribute :name, value ; end

    def publish(scientist_result)
      return if Rails.env.test? && !LabTech.publish_results_in_test_mode?
      LabTech::Result.record_a_science( self, scientist_result )
    end

    # I don't encourage the willy-nilly destruction of experimental results...
    # ...but sometimes you just need to start over.
    def purge_data
      delete_and_count = ->(scope) {
        n0, n1 = 0, 0
        transaction do
          n0 = scope.count
          scope.delete_all
          n1 = scope.count
        end
        n0 - n1
      }

      n = delete_and_count.call( LabTech::Observation.where(result_id: self.result_ids) )
      m = delete_and_count.call( self.results )

      update_attributes(
        equivalent_count:  0,
        timed_out_count:   0,
        other_error_count: 0,
      )

      puts "Deleted #{m} result(s) and #{n} observations"
    end

    def run(*)
      increment_run_count
      provide_default_cleaner
      super
    end

    # TODO: DRY up the io.puts structure between this and compare_mismatches
    def summarize_errors(limit: nil, io: $stdout)
      errors = results.other_error
      return if errors.empty?
      errors = errors.limit(limit) if limit

      io.puts
      io.puts "=" * 100
      io.puts "Comparing results for #{name}:"
      io.puts

      errors.each do |result|
        io.puts
        io.puts "-" * 100
        io.puts "Result ##{result.id}"
        result.candidates.each do |observation|
          puts "  * " + observation.exception_class + ":  " + observation.exception_message
        end
        io.puts "-" * 100
      end

      io.puts
      io.puts "=" * 100
      io.puts
      nil
    end

    def summarize_results
      puts "", summary, ""
    end

    def summary
      reload
      LabTech::Summary.new(self)
    end

    private

    def increment_run_count
      LabTech.run_count[self.name] += 1
    end

    def provide_default_cleaner
      return if cleaner.present?
      clean { |value| LabTech::DefaultCleaner.call(value) }
    end
  end
end
