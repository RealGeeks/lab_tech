require 'rails_helper'

RSpec.describe LabTech::Summary do
  let!(:experiment) { LabTech::Experiment.create(name: "wibble", percent_enabled: 100) }
  let(:summary_text) { experiment.summary.to_s }

  def record_experiment(cont: "foo", cand: "foo", speedup_factor: nil, baseline: 1.0, comparison: nil)
    LabTech.publish_results_in_test_mode do

      LabTech.science "wibble" do |e|
        e.use { cont.respond_to?(:call) ? cont.call : cont }
        e.try { cand.respond_to?(:call) ? cand.call : cand }
      end

      # Don't bother stubbing Scientist's clock; you'll get the wrong results 50%
      # of the time because it runs the `try` and `use` blocks in random order,
      # and then you'll be very very confused.
      if speedup_factor && comparison.nil?
        baseline = baseline.to_f
        comparison = \
          case
          when speedup_factor  > 0 ; +1.0 * baseline / speedup_factor
          when speedup_factor == 0 ; +1.0 * baseline
          else                     ; -1.0 * baseline * speedup_factor
          end
      end

      if baseline && comparison && speedup_factor.nil?
        speedup_factor = LabTech::Speedup.compute_factor(baseline, comparison)
      end

      if baseline && comparison && speedup_factor
        result = experiment.results.last
        result.update({
          control_duration:   baseline,
          candidate_duration: comparison,
          speedup_factor:     speedup_factor,
          time_delta:         baseline - comparison,
        })

        # Technically, we only needed to update the result... but for consistency, let's update the observations too.
        result.control          .update duration: baseline
        result.candidates.first .update duration: comparison
      end

    end # LabTech.publish_results_in_test_mode do
  end

  def wtf
    puts
    puts "", "Experiment"   ; tp experiment
    puts "", "Results"      ; tp experiment.results
    puts "", "Observations" ; tp experiment.observations
    puts
  end

  context "when there are no results" do
    before do
      expect( experiment.results ).to be_empty # precondition check
    end

    it "says there are no results" do
      expect( summary_text ).to match( /No results for experiment/ )
    end
  end

  context "when the only result is a mismatch" do
    before do
      record_experiment cont: "foo", cand: "bar"
    end

    it "reports the correct counts" do
      aggregate_failures do
        expect( summary_text ).to_not include( "0 of 1 (0.00%) correct" )
        expect( summary_text ).to     include( "1 of 1 (100.00%) mismatched" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) timed out" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) raised errors" )
      end
    end
  end

  context "when the only result is an error" do
    before do
      record_experiment cont: "foo", cand: ->{ raise "nope" }
    end

    it "reports the correct counts" do
      aggregate_failures do
        expect( summary_text ).to_not include( "0 of 1 (0.00%) correct" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) mismatched" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) timed out" )
        expect( summary_text ).to     include( "1 of 1 (100.00%) raised errors" )
      end
    end
  end

  context "when the only result is a timeout" do
    before do
      record_experiment cont: "foo", cand: ->{ raise Timeout::Error, "too slow" }
    end

    it "reports the correct counts" do
      aggregate_failures do
        expect( summary_text ).to_not include( "0 of 1 (0.00%) correct" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) mismatched" )
        expect( summary_text ).to     include( "1 of 1 (100.00%) timed out" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) raised errors" )
      end
    end
  end

  context "when there are correct results that somehow lack any timing data" do
    before do
      record_experiment
      experiment.results.update_all time_delta: nil, speedup_factor: nil
    end

    it "reports the correct counts" do
      aggregate_failures do
        expect( summary_text ).to     include( "1 of 1 (100.00%) correct" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) mismatched" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) timed out" )
        expect( summary_text ).to_not include( "0 of 1 (0.00%) raised errors" )
      end
    end

    it "doesn't try to print the big table thingy" do
      expect( summary_text ).to_not include( "Time deltas/speedups:" )
    end
  end

  describe "when there are correct results that include timing data" do
    def expect_percentile_line(percentile, *expected_strings)
      line = summary_text.lines.detect { |e| e =~ /\s#{percentile.to_i}%/ }
      aggregate_failures do
        expected_strings.each do |string|
          expect( line ).to include( string )
        end
      end
    end

    context "with a speedup factor of 0x (yawn)" do
      before do
        record_experiment speedup_factor: 0

        # Make sure we got the math right there...
        result = experiment.results.first
        aggregate_failures do
          expect( result.control.duration          ).to be_within( 0.001 ).of( 1.0 )
          expect( result.candidates.first.duration ).to be_within( 0.001 ).of( 1.0 )
        end
      end

      it "reports the correct counts" do
        aggregate_failures do
          expect( summary_text ).to     include( "1 of 1 (100.00%) correct" )
          expect( summary_text ).to_not include( "0 of 1 (0.00%) mismatched" )
          expect( summary_text ).to_not include( "0 of 1 (0.00%) timed out" )
          expect( summary_text ).to_not include( "0 of 1 (0.00%) raised errors" )
        end
      end

      it "prints the stats visualization, including the correct speedup factor" do
        expect_percentile_line( 50, "+0.0x" )
      end
    end

    context "with a speedup factor of 10x (yay!)" do
      before do
        record_experiment speedup_factor: 10

        # Make sure we got the math right there...
        result = experiment.results.first
        aggregate_failures do
          expect( result.control.duration          ).to be_within( 0.001 ).of( 1.0 )
          expect( result.candidates.first.duration ).to be_within( 0.001 ).of( 0.1 )
        end
      end

      it "prints the stats visualization, including the correct speedup factor" do
        expect_percentile_line( 50, "+10.0x" )
      end
    end

    context "with a speedup factor of -10x (boo!)" do
      before do
        record_experiment speedup_factor: -10

        # Make sure we got the math right there...
        result = experiment.results.first
        aggregate_failures do
          expect( result.control.duration          ).to be_within( 0.001 ).of(  1.0 )
          expect( result.candidates.first.duration ).to be_within( 0.001 ).of( 10.0 )
        end
      end

      it "prints the stats visualization, including the correct speedup factor" do
        expect_percentile_line( 50, "-10.0x" )
      end
    end

    context "with multiple results and different speedups" do
      before do
        record_experiment speedup_factor: -10
        record_experiment speedup_factor:  -2
        record_experiment speedup_factor:   0
        record_experiment speedup_factor:   2
        record_experiment speedup_factor:  10
      end

      it "reports the correct counts" do
        aggregate_failures do
          expect( summary_text ).to     include( "5 of 5 (100.00%) correct" )
          expect( summary_text ).to_not include( "0 of 5 (0.00%) mismatched" )
          expect( summary_text ).to_not include( "0 of 5 (0.00%) timed out" )
          expect( summary_text ).to_not include( "0 of 5 (0.00%) raised errors" )
        end
      end

      it "reports median time deltas, as well as 5th & 95th percentiles, on their own line" do
        time_delta_line = summary_text.lines.detect { |e| e =~ /Median time delta/i }
        expect( time_delta_line ).to be_present

        expect( time_delta_line ).to include( "-9.000s" ) # 5th percentile
        expect( time_delta_line ).to include( "+0.000s" ) # Median
        expect( time_delta_line ).to include( "+0.900s" ) # 95th percentile
      end

      it "prints the stats visualization, including the correct speedup factor" do
        # This is effectively acting as an integration test for the Array#percentile method we've monkeypatched in
				aggregate_failures do
					expect_percentile_line(  0, "-10.0x" )
					expect_percentile_line( 20, "-10.0x" )

					expect_percentile_line( 25,  "-2.0x" )
					expect_percentile_line( 40,  "-2.0x" )

					expect_percentile_line( 45,  "+0.0x" )
					expect_percentile_line( 60,  "+0.0x" )

					expect_percentile_line( 65,  "+2.0x" )
					expect_percentile_line( 80,  "+2.0x" )

					expect_percentile_line( 85, "+10.0x" )
					expect_percentile_line(100, "+10.0x" )
				end
      end
    end

    context "real-world(ish) data that led to a scaling error" do
      before do
        record_experiment baseline: 1.7367, speedup_factor: 10.9099
        record_experiment baseline: 0.0642, speedup_factor: -3.2183
        record_experiment baseline: 0.0702, speedup_factor: -1.0906
        record_experiment baseline: 0.0552, speedup_factor:  1.1123
        record_experiment baseline: 0.0539, speedup_factor:  1.1808
        record_experiment baseline: 0.0554, speedup_factor: -1.1269
      end

      it "renders properly" do
				aggregate_failures do
					expect_percentile_line(  0, "-3.2x" )
					expect_percentile_line( 15, "-3.2x" )
					expect_percentile_line( 20, "-1.1x" )
					expect_percentile_line( 30, "-1.1x" )
					expect_percentile_line( 35, "-1.1x" )
					expect_percentile_line( 50, "-1.1x" )
					expect_percentile_line( 55, "+1.1x" )
					expect_percentile_line( 65, "+1.1x" )
					expect_percentile_line( 70, "+1.2x" )
					expect_percentile_line( 80, "+1.2x" )
					expect_percentile_line( 85, "+10.9x" )
					expect_percentile_line(100, "+10.9x" )
				end

      end
    end

    context "real-world(ish) data that led to a scaling error, part 2" do
			before do
				record_experiment baseline: 0.0030516        , comparison: 0.00306088
				record_experiment baseline: 0.000261548      , comparison: 0.00220928
				record_experiment baseline: 0.000781327      , comparison: 0.00279742
				record_experiment baseline: 0.00201508       , comparison: 0.002386
				record_experiment baseline: 0.000593603      , comparison: 0.00275979
				record_experiment baseline: 0.000259521      , comparison: 0.0021131
				record_experiment baseline: 0.000673067      , comparison: 0.00250636
				record_experiment baseline: 0.00229586       , comparison: 0.00285059
				record_experiment baseline: 0.002911         , comparison: 0.00275513
				record_experiment baseline: 0.00275274       , comparison: 0.00251802
				record_experiment baseline: 0.000236285      , comparison: 0.00198174
				record_experiment baseline: 0.000225291      , comparison: 0.00257419
				record_experiment baseline: 0.000356831      , comparison: 0.00244557
				record_experiment baseline: 0.000287118      , comparison: 0.00248476
				record_experiment baseline: 0.000556486      , comparison: 0.00261352
				record_experiment baseline: 0.00237066       , comparison: 0.00265087
				record_experiment baseline: 0.00183386       , comparison: 0.00211302
				record_experiment baseline: 0.00296087       , comparison: 0.00294441
				record_experiment baseline: 0.00031988       , comparison: 0.00323599
			end

      it "renders properly" do
				aggregate_failures do
          expect_percentile_line(  0, "-11.4x" )
          expect_percentile_line( 50,  "-3.7x" )
          expect_percentile_line(100,  "+1.1x" )
				end
      end
    end
  end
end
