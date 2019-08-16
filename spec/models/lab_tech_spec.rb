require 'rails_helper'

RSpec.describe LabTech do

  describe ".science" do
    let(:experiment) { instance_double(LabTech::Experiment) }

    before do
      allow( LabTech::Experiment ).to receive( :named ).with( "wibble" ).and_return( experiment )
    end

    it "finds the named LabTech::Experiment.science, yields it to the block, then runs it" do
      yielded = nil
      expect( experiment ).to receive( :run ).with( nil )
      LabTech.science "wibble", foo: "spam" do |exp|
        yielded = exp
      end

      expect( yielded ).to be( experiment )
    end
  end

end
