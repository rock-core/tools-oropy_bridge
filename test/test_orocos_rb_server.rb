require '../ruby/lib/oropy_bridge/oropy_bridge'

server = OropyBridge::OrocosRbServer.new("statistics::CumulativeTask" => "stats")

server.deploy 

config = Hash.new
config["debug_conversion"] = true

puts "known tasks:"
server.tasks.each do |k,_|
    puts k
end

a_new_port = Hash.new
a_new_port["portname"] = "rbs1"
a_new_port["type"] = "/base/samples/RigidBodyState"
a_new_port["slice"] = "position"
a_new_port["vectorIdx"] = 0
a_new_port["period"] = 0.1
a_new_port["useTimeNow"] = true

server.addPort("/stats",a_new_port)

server.apply_config("/stats", config)

server.configure("/stats")

puts
puts "Task  Type  Orocos_Type"
puts "--- Input ports ---"
server.tasks["/stats"].each_input_port do |p|
    puts "#{p.name}  #{p.type_name}  #{p.orocos_type_name}"
end

puts "\n--- Output ports ---"
server.tasks["/stats"].each_output_port do |p|
    puts "#{p.name}  #{p.type_name}  #{p.orocos_type_name}"
end
puts

server.start("/stats")

puts "Press Enter to go on!"
gets

(1..10).each do |idx|
    server.write_vector("/stats","rbs1_raw",[0.0,2.0,3.0])
    sleep(0.1)
    puts "debug (#{idx}):"
    puts server.read_vector("/stats","debug_0")
    puts "stats:"
    puts server.read("/stats", "stats_0")
end

server.stop("/stats")
server.cleanup("/stats")

server.stop_deployments
