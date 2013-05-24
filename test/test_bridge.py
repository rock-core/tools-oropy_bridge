import oropy_bridge
import time

client = oropy_bridge.Client(ruby_cmd=["oropy_server"]) # --log

started_tasks = client.deploy({"statistics::CumulativeTask" : "stats"})

print "deployed:"
for t in started_tasks:
    print "    %s"%t

config = { "debug_conversion" : True }

a_new_port = {
        "portname" : "rbs1",
        "type" : "/base/samples/RigidBodyState",
        "slice" : "position",
        "vectorIdx" : 0,
        "period" : 0.1,
        "useTimeNow" : True
}

client.operation("/stats","addPort",a_new_port)
print "added port"

client.apply_config("/stats",config)
print "applied config"

client.configure("/stats")

client.start("/stats")

print "Started - Press <Enter> to continue"
raw_input()

for i in xrange(10):
    client.write_vector("/stats","rbs1_raw",[0.0,2.0,3.0])
    time.sleep(0.1)
    print "debug (%i):"%i
    print client.read_vector("/stats", "debug_0")
    print "stats:"
    print client.read("/stats","stats_0")

client.stop("/stats")
client.cleanup("/stats")

client.stop_deployments()
