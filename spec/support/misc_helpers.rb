def wtf
  puts "", "#" * 100
  puts "\nExperiments"  ; tp LabTech::Experiment.all
  puts "\nResults"      ; tp LabTech::Result.all
  puts "\nObservations" ; tp LabTech::Observation.all
  puts "", "#" * 100
end
