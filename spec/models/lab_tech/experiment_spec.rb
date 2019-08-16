require 'rails_helper'
require SPEC_ROOT.join('support/misc_helpers.rb')

RSpec.describe LabTech::Experiment do
  around do |example|
    described_class.publish_results_in_test_mode = true
    example.run
    described_class.publish_results_in_test_mode = false
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
        expect( LabTech::Result ).to receive( :record_a_science ).with( experiment, instance_of(Scientist::Result) )

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
    end
  end
end
