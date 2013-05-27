import oropy_bridge
import time

client = oropy_bridge.Client(ruby_cmd=["oropy_server","-v"]) # --log

started_tasks = client.deploy({"statistics::CumulativeTask" : "stats"})

print "deployed:"
for t in started_tasks:
    print "    %s"%t

config = { "debug_conversion" : True, "aggregator_max_latency" : 0.1}

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


for i in xrange(50):
    client.write_vector("/stats","rbs1_raw",[float(i),2.0,3.0])
    time.sleep(0.1)
    print "debug (%i):"%i
    print client.read_vector("/stats", "debug_0")
    print "stats:"
    stats = client.read("/stats","stats_0")
    if stats: print "(%i) t=%.6f mean: %f"%(stats.get("n"),stats.get("time"),stats.get("mean")[0])
    else: print None


client.stop("/stats")
client.cleanup("/stats")

client.stop_deployments()
