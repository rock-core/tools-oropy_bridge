''' Using orogen components from within python.

This module allows to deploy orogen components and use them similiar to the ruby interface.

Usage is:

>>> import oropy_bridge
>>> 
>>> client = oropy_bridge.Client()#(ruby_cmd=["oropy_server"]) # --log
>>> 
>>> started_tasks = client.deploy({"statistics::CumulativeTask" : "stats"})
>>> 
>>> config = { "debug_conversion" : True, "aggregator_max_latency" : 0.1}
>>> 
>>> a_new_port = {
>>>         "portname" : "rbs1",
>>>         "type" : "/base/samples/RigidBodyState",
>>>         "slice" : "position",
>>>         "vectorIdx" : 0,
>>>         "period" : 0.1,
>>>         "useTimeNow" : True
>>> }
>>> 
>>> client.operation("/stats","addPort",a_new_port)
>>> client.apply_config("/stats",config)
>>> client.configure("/stats")
>>> client.start("/stats")
>>> 
>>> for i in xrange(50):
>>>     client.write_vector("/stats","rbs1_raw",[float(i),2.0,3.0])
>>>     time.sleep(0.1)
>>>     print "stats:"
>>>     stats = client.read("/stats","stats_0")
>>>     if stats: print "(%i) t=%.6f mean: %f"%(stats.get("n"),stats.get("time"),stats.get("mean")[0])
>>>     else: print None
>>> 
>>> client.stop("/stats")
>>> client.cleanup("/stats")
>>> client.stop_deployments()

'''
from oropy_bridge import *
