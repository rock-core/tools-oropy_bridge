require '../ruby/lib/oropy_bridge/oropy_bridge'

handler = OropyBridge::OrocosRb.new

handler.deploy("statistics::CumulativeTask" => "stats")

config = Hash.new
config["debug_conversion"] = true

puts "known tasks:"
handler.tasks.each do |k,_|
    puts k
end

a_new_port = Hash.new
a_new_port["portname"] = "rbs1"
a_new_port["type"] = "/base/samples/RigidBodyState"
a_new_port["slice"] = "position"
a_new_port["vectorIdx"] = 0
a_new_port["period"] = 0.1
a_new_port["useTimeNow"] = true

handler.operation("/stats","addPort",[a_new_port])

handler.apply_config("/stats", config)

handler.configure("/stats")

puts
puts "Task  Type  Orocos_Type"
puts "--- Input ports ---"
handler.tasks["/stats"].each_input_port do |p|
    puts "#{p.name}  #{p.type_name}  #{p.orocos_type_name}"
end

puts "\n--- Output ports ---"
handler.tasks["/stats"].each_output_port do |p|
    puts "#{p.name}  #{p.type_name}  #{p.orocos_type_name}"
end
puts

handler.start("/stats")

puts "Press Enter to go on!"
gets

(1..10).each do |idx|
    handler.write_vector("/stats","rbs1_raw",[0.0,2.0,3.0])
    sleep(0.1)
    puts "debug (#{idx}):"
    puts handler.read_vector("/stats","debug_0")
    puts "stats:"
    puts handler.read("/stats", "stats_0")
end

handler.stop("/stats")
handler.cleanup("/stats")

handler.stop_deployments
