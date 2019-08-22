require 'rails_helper'
require SPEC_ROOT.join('support/misc_helpers.rb')

RSpec.describe LabTech::Result, type: :model do
  let!(:experiment) { LabTech::Experiment.create(name: "wibble", percent_enabled: 100) }

  around do |example|
    LabTech.publish_results_in_test_mode do
      example.run
    end
  end

  def wibble_wobble!( fabricated_durations: {} )
    LabTech.science "wibble" do |e|
      e.use { :wibble }
      e.try { :wobble }

      # As of 1.3.0, Scientist allows you to provide fake timing data :)
      e.fabricate_durations_for_testing_purposes( fabricated_durations )
    end
  end

  describe ".record_a_science" do
    let(:result)    { LabTech::Result.last }
    let(:control)   { result.control }
    let(:candidate) { result.candidates.first }

    it "creates records for the result and both observations" do
      expect { wibble_wobble! } \
        .to  change { LabTech::Result      .count }.by( 1 )
        .and change { LabTech::Observation .count }.by( 2 )

      aggregate_failures do
        expect( result.equivalent   ).to be false
        expect( result.raised_error ).to be false

        expect( result.control.value          ).to eq( :wibble )
        expect( result.candidates.first.value ).to eq( :wobble )
      end
    end

    describe "timing data" do
      context "when one behavior takes zero time" do
        let(:fabricated_durations) { { "control" => 0.5, "candidate" => 0.0 } }

        specify "the saved records contain timing data (durations, delta, but no speedup)" do
          wibble_wobble! fabricated_durations: fabricated_durations

          expect( control.duration          ).to eq(  0.5 )
          expect( candidate.duration        ).to eq(  0.0 )
          expect( result.control_duration   ).to eq(  0.5 )
          expect( result.candidate_duration ).to eq(  0.0 )
          expect( result.time_delta         ).to eq(  0.5 )
          expect( result.speedup_factor     ).to be nil
        end
      end

      context "when both behaviors take zero time" do
        let(:fabricated_durations) { { "control" => 0.0, "candidate" => 0.0 } }

        specify "the saved records contain timing data (durations, delta, but no speedup)" do
          wibble_wobble! fabricated_durations: { "control" => 0.0, "candidate" => 0.0 }

          expect( control.duration          ).to eq( 0.0 )
          expect( candidate.duration        ).to eq( 0.0 )
          expect( result.control_duration   ).to eq( 0.0 )
          expect( result.candidate_duration ).to eq( 0.0 )
          expect( result.time_delta         ).to eq( 0.0 )
          expect( result.speedup_factor     ).to be nil
        end
      end

      context "when both behaviors take exactly the same time" do
        let(:fabricated_durations) { { "control" => 0.5, "candidate" => 0.5 } }

        specify "the saved records contain timing data (durations, delta, speedup)" do
          wibble_wobble! fabricated_durations: fabricated_durations

          expect( control.duration          ).to eq( 0.5 )
          expect( candidate.duration        ).to eq( 0.5 )
          expect( result.control_duration   ).to eq( 0.5 )
          expect( result.candidate_duration ).to eq( 0.5 )
          expect( result.time_delta         ).to eq( 0.0 )
          expect( result.speedup_factor     ).to eq( 0.0 )
        end

        specify "the result has a Speedup object" do
          wibble_wobble! fabricated_durations: fabricated_durations
          speedup = result.speedup

          expect( speedup ).to be_kind_of( LabTech::Speedup )

          expect( speedup.time   ).to eq( 0.0 )
          expect( speedup.factor ).to eq( 0.0 )
        end
      end

      context "when one behavior takes twice as long as the other" do
        let(:fabricated_durations) { { "control" => 0.5, "candidate" => 1.0 } }

        specify "the saved records contain timing data (durations, delta, speedup)" do
          wibble_wobble! fabricated_durations: fabricated_durations

          expect( control.duration      ).to eq(  0.5 )
          expect( candidate.duration    ).to eq(  1.0 )
          expect( result.time_delta     ).to eq( -0.5 )
          expect( result.speedup_factor ).to eq( -2.0 )
        end
      end
    end

    context "when a comparator is provided" do
      before do
        LabTech.science "wibble" do |e|
          e.use { :wibble }
          e.try { :WIBBLE }
          e.compare { |control, candidate| control.to_s.upcase == candidate.to_s.upcase }
        end
      end

      specify "we use it to check equivalency" do
        expect( result ).to be_equivalent
      end
    end

    context "when the candidate raises an exception" do
      before do
        LabTech.science "wibble" do |e|
          e.use { :wibble }
          e.try { raise "nope" }
        end
      end

      specify "we don't asplode" do
        aggregate_failures do
          expect( result   .raised_error? ).to be true
          expect( control  .raised_error? ).to be false
          expect( candidate.raised_error? ).to be true

          expect( result   .timed_out? ).to be false
          expect( control  .timed_out? ).to be false
          expect( candidate.timed_out? ).to be false

          expect( candidate.exception_class     ).to eq( "RuntimeError" )
          expect( candidate.exception_message   ).to eq( "nope" )
          expect( candidate.exception_backtrace ).to be_present
        end
      end
    end

    context "when the exception raised is a Timeout::Error" do
      before do
        LabTech.science "wibble" do |e|
          e.use { :wibble }
          e.try { raise Timeout::Error, "nope" }
        end
      end

      specify "we mark the result as :timed_out AND :raised_error" do
        aggregate_failures do
          expect( result   .raised_error? ).to be true
          expect( control  .raised_error? ).to be false
          expect( candidate.raised_error? ).to be true

          expect( result   .timed_out? ).to be true
          expect( control  .timed_out? ).to be false
          expect( candidate.timed_out? ).to be true

          expect( candidate.exception_class     ).to eq( "Timeout::Error" )
          expect( candidate.exception_message   ).to eq( "nope" )
          expect( candidate.exception_backtrace ).to be_present
        end

        expect( LabTech::Result.timed_out ).to include( result )
      end
    end

    specify "Results that time out are *not* also counted as mismatches" do
      LabTech.science "wibble" do |e|
        e.use { :wibble }
        e.try { raise Timeout::Error, "nope" }
      end

      aggregate_failures do
        expect( result.equivalent?   ).to be false
        expect( result.timed_out?    ).to be true
        expect( result.raised_error? ).to be true

        expect( described_class.correct     ).to_not include( result )
        expect( described_class.mismatched  ).to_not include( result )
        expect( described_class.timed_out   ).to     include( result )
        expect( described_class.other_error ).to_not include( result )
      end

      expect( LabTech::Result.timed_out ).to include( result )
    end
  end
end
