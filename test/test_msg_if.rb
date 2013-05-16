#!/usr/bin/env ruby

require 'msgpack'
require '../ruby/lib/oropy_bridge/oropy_bridge'

r_caller, w_msg = IO.pipe
r_msg, w_caller = IO.pipe

handler = OropyBridge::OrocosRb.new
cal = OropyBridge::Caller.new r_caller, w_caller, handler

calT = Thread.new { while cal.process; end; w_caller.close }

def wait_for_reply(cmd, r_msg)
    unpacker = MessagePack::Unpacker.new(r_msg)
    while 1
        begin
            unpacker.each do |obj|
                if obj[0] == "OtherError"
                    puts "#{obj[0]} : #{obj[1][0]}(#{obj[1][1]})"
                    obj[1][2].each do |l|
                        puts l
                    end
                    break
                elsif obj[0][-5,5] ==  "Error"
                    puts "#{obj[0]} : #{obj[1][0]}"
                    obj[1][1].each do |l|
                        puts l
                    end
                    break
                elsif obj[0] == cmd
                    return obj[1]
                end
            end
        rescue EOFError => e
            break
        end
    end
    Nil
end

def send_cmd(cmd, r_msg, packer)
    packer.write(cmd).flush()
    reply = wait_for_reply(cmd[0],r_msg)
    puts "--- got reply for #{cmd[0]}"
    reply
end

packer = MessagePack::Packer.new(w_msg)

deploy_cmd = [ "deploy", [{"statistics::CumulativeTask" => "stats"}]]
send_cmd(deploy_cmd,r_msg,packer)


a_new_port = Hash.new
a_new_port["portname"] = "rbs1"
a_new_port["type"] = "/base/samples/RigidBodyState"
a_new_port["slice"] = "position"
a_new_port["vectorIdx"] = 0
a_new_port["period"] = 0.1
a_new_port["useTimeNow"] = true
add_port_cmd = [ "operation", [ "/stats", "addPort", [a_new_port]]]
send_cmd(add_port_cmd,r_msg,packer)

config = Hash.new
config["debug_conversion"] = true
apply_config_cmd = [ "apply_config", ["/stats", config]]
send_cmd(apply_config_cmd,r_msg,packer)

send_cmd(["configure",["/stats"]],r_msg,packer)
send_cmd(["start",["/stats"]],r_msg,packer)

puts "Press Enter to send data!"
gets

write_cmd = ["write_vector",["/stats","rbs1_raw",[0.0,2.0,3.0]]]
read_cmd = ["read",["/stats","stats_0"]]
puts send_cmd(read_cmd,r_msg,packer)
sleep(0.1)
(1..10).each do |idx|
    send_cmd(write_cmd,r_msg,packer)
    sleep(0.1)
    puts send_cmd(read_cmd,r_msg,packer)
end

send_cmd(["stop",["/stats"]],r_msg,packer)
send_cmd(["cleanup",["/stats"]],r_msg,packer)

stop_deployments_cmd = ["stop_deployments"]
send_cmd(stop_deployments_cmd,r_msg,packer)

w_msg.close

calT.join
#backT.join
