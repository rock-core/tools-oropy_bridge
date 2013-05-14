require 'oropy_bridge/oropy_bridge'

# The toplevel namespace for oropy_bridge
#
# oropy bridge is a bridge between python and orocos.rb to control tasks,
# feed data into tasks and get data back.
require 'utilrb/logger'
module OropyBridge
    extend Logger::Root('OropyBridge', Logger::WARN)
end

