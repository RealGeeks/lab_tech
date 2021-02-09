require 'rails_helper'
require SPEC_ROOT.join('support/misc_helpers.rb')

RSpec.describe LabTech::Experiment do
  around do |example|
    LabTech.publish_results_in_test_mode do
      example.run
    end
  end

  def wtf
    puts "", "#" * 100
    puts "\nExperiments"  ; tp LabTech::Experiment.all
    puts "\nResults"      ; tp LabTech::Result.all
    puts "\nObservations" ; tp LabTech::Observation.all
    puts "", "#" * 100
  end

  describe ".science" do
    let!(:experiment) { described_class.create(name: "wibble", percent_enabled: 0) }

    context "by default" do
      it "runs the .use block (the 'control') but not the .try block (the 'candidate')" do
        control, candidate = false, false
        LabTech.science "wibble" do |e|
          e.use { control   = true }
          e.try { candidate = true }
        end

        expect( control   ).to be true
        expect( candidate ).to be false
      end
    end

    context "when the experiment is #enabled?" do
      before do
        experiment.update_attribute(:percent_enabled, 100)
      end

      it "runs the .try block (the 'candidate') when that experiment is #enabled?" do
        control, candidate = false, false
        LabTech.science "wibble" do |e|
          e.use { control   = true }
          e.try { candidate = true }
        end

        expect( control   ).to be true
        expect( candidate ).to be true
      end

      it "records the results when the experiment is run" do
        expect( LabTech::Result ).to \
          receive( :record_a_science ) \
          .with( experiment, instance_of(Scientist::Result), anything )

        LabTech.science "wibble" do |e|
          e.use { :wibble }
          e.try { :wobble }
        end
      end

      describe "value-cleaning behavior" do
        let(:result) { experiment.results.first }

        specify "if a #clean block IS provided, it is used" do
          LabTech.science "wibble" do |e|
            e.use { :control }
            e.try { :candidate }
            e.clean { |value| value.to_s.upcase }
          end

          result = experiment.results.first
          expect( result ).to be_kind_of( LabTech::Result )

          expect( result.control          .value ).to eq( "CONTROL" )
          expect( result.candidates.first .value ).to eq( "CANDIDATE" )
        end

        specify "if a #clean block IS NOT provided, DefaultCleaner is used" do
          default = LabTech::DefaultCleaner
          expect( default ).to receive( :call ).with( :control   ).and_return( "Yes indeedily!" )
          expect( default ).to receive( :call ).with( :candidate ).and_return( "You suck-diddly-uck, Flanders!" )

          LabTech.science "wibble" do |e|
            e.use { :control }
            e.try { :candidate }
          end

          result = experiment.results.first
          expect( result.control          .value ).to eq( "Yes indeedily!" )
          expect( result.candidates.first .value ).to eq( "You suck-diddly-uck, Flanders!" )
        end
      end

      describe "diff-generating behavior" do
        let(:result) { experiment.results.first }

        specify "if a #diff block IS provided, it is used" do
          LabTech.science "wibble" do |e|
            e.use { :control }
            e.try { :candidate }

            e.diff { |control, candidate|
              # Make sure we pass values to the diff block, not the observations themselves
              raise "nope" if control.is_a?(Scientist::Observation)
              raise "nope" if candidate.is_a?(Scientist::Observation)
              "this is a diff"
            }
          end

          result = experiment.results.first
          expect( result ).to be_kind_of( LabTech::Result )

          expect( result.control          .diff ).to be_blank # because it's the reference against which candidates are diffed
          expect( result.candidates.first .diff ).to eq( "this is a diff" )
        end

        specify "if a #diff block IS NOT provided, nothing untoward occurs" do
          LabTech.science "wibble" do |e|
            e.use { :control }
            e.try { :candidate }
          end

          result = experiment.results.first
          expect( result.control          .diff ).to be_blank # because it's the reference against which candidates are diffed
          expect( result.candidates.first .diff ).to be_blank # because no block was provided
        end
      end

      describe "result counts" do
        specify "when results are equivalent" do
          LabTech.science "wibble" do |e|
            e.use { :wibble }
            e.try { :wibble }
          end

          experiment.reload
          aggregate_failures do
            expect( experiment.equivalent_count  ).to eq( 1 )
            expect( experiment.timed_out_count   ).to eq( 0 )
            expect( experiment.other_error_count ).to eq( 0 )
          end
        end
      end

      describe "summary output" do
        before do
          LabTech.science "wibble" do |e|
            e.use { :wibble } ; e.try { :wibble }
          end
          LabTech.science "wibble" do |e|
            e.use { :wibble } ; e.try { :florp }
          end
          LabTech.science "wibble" do |e|
            e.use { :wibble } ; e.try { fail "nope" }
          end
        end

        specify "compare_mismatches" do
          io = StringIO.new
          LabTech.compare_mismatches "wibble", io: io
          out = io.string
          expect(out).to match( /Comparing results for wibble:/ )
          expect(out).to match( /control # => :wibble/ )
          expect(out).to match( /candidate # => :florp/ )
        end

        specify "summarize_errors" do
          io = StringIO.new
          LabTech.summarize_errors "wibble", io: io
          out = io.string
          expect(out).to match( /Summarizing errors for wibble:/ )
          expect(out).to include( "  * RuntimeError:  nope" )
        end
      end
    end
  end
end
