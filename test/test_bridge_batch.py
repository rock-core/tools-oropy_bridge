import oropy_bridge
import time

client = oropy_bridge.Client(ruby_cmd=["oropy_server","-v"],batch_mode=True) # --log

config = { "debug_conversion" : True, "aggregator_max_latency" : 0.1}

a_new_port = {
        "portname" : "rbs1",
        "type" : "/base/samples/RigidBodyState",
        "slice" : "position",
        "vectorIdx" : 0,
        "period" : 0.1,
        "useTimeNow" : True
}

client.deploy({"statistics::CumulativeTask" : "stats"})
client.operation("/stats","addPort",a_new_port)
client.apply_config("/stats",config)
client.configure("/stats")
client.start("/stats")

for i in xrange(20):
    client.write_vector("/stats","rbs1_raw",[float(i),2.0,3.0])
    client.sleep(0.1)
    client.read_vector("/stats", "debug_0")
    client.read("/stats","stats_0")

client.stop("/stats")
client.cleanup("/stats")
client.stop_deployments()

result = client.run()

print "result:"
for r in result:
    if r[0] == "read_vector":
        print "debug out:",r[1]
    elif r[0] == "read":
        print "stats:"
        stats = r[1]
        if stats: print "(%i) t=%.6f mean: %f"%(stats.get("n"),stats.get("time"),stats.get("mean")[0])
        else: print None
