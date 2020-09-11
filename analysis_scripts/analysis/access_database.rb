require 'optparse'
require 'openstudio-analysis'

options = {}
OptionParser.new do |opt|
  opt.on('--analysis_id ID') { |o| options[:analysis_id] = o }
  opt.on('--host host') { |o| options[:host] = o }
end.parse!

puts options

# Save some data to the database
puts 'Saving data back into the database via rails'
analysis = Analysis.find(options[:analysis_id])
analysis.results[:finalization] = {}

puts 'Initializing ServerApi'
api = OpenStudio::Analysis::ServerApi.new(hostname: options[:host])
puts api
r = api.get_analysis_results(options[:analysis_id])

# define variables
datapoint_hash_ids = {} # not used for anything right now
high_uh_clg_ids = {}
high_uh_htg_ids = {}
uh_limit = 300.0
lowest_eui_id = nil
eui_min = nil
# todo - add in test for number of measures with warnings using new warning section of openstudio_results

# loop through datapoints
puts "looping through datapoints"
r[:data].each do |datapoint|

  # id for datapoint
  id = datapoint[:_id]

  # store os_results info
  datapoint_outputs = {}
  datapoint_outputs[:eui] = datapoint[:"openstudio_results.eui"]
  datapoint_outputs[:uh_clg] = datapoint[:"openstudio_results.unmet_hours_during_occupied_cooling"]
  datapoint_outputs[:uh_htg] = datapoint[:"openstudio_results.unmet_hours_during_occupied_heating"]

  # store in prmary hash
  datapoint_hash_ids[id] = datapoint_outputs

  # lowest EUI check
  if lowest_eui_id.nil?
    lowest_eui_id = id
    eui_min = datapoint_outputs[:eui]
  elsif datapoint_outputs[:eui] < eui_min
    lowest_eui_id = id
    eui_min = datapoint_outputs[:eui] 
  end

  # high_uh checks
  if datapoint_outputs[:uh_clg] > uh_limit
    high_uh_clg_ids[id] = datapoint_outputs
  end
  if datapoint_outputs[:uh_htg] > uh_limit
    high_uh_htg_ids[id] = datapoint_outputs
  end

end

puts "Lowest EUI of #{eui_min} belongs to datapoint #{lowest_eui_id}"
puts "#{high_uh_clg_ids.size} datapoints have more than #{uh_limit} hours of unmet occupied cooling."
puts "#{high_uh_htg_ids.size} datapoints have more than #{uh_limit} hours of unmet occupied heating."

# update database
puts "Updating Analysis results"
analysis.results[:finalization][:high_uh_clg] = high_uh_clg_ids
analysis.results[:finalization][:high_uh_htg] = high_uh_htg_ids
analysis.results[:finalization][:low_eui] = lowest_eui_id
puts analysis.results

analysis.save!
