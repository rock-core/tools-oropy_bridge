require 'orocos'
include Orocos
Orocos.initialize

ENV['BASE_LOG_LEVEL'] = 'INFO'
ENV['BASE_LOG_FORMAT'] = 'SHORT'
ENV['ORO_LOGLEVEL'] = '3'

def type_to_ruby(value)
    if value.kind_of?(Typelib::CompoundType)
        result = Hash.new
        value.each_field do |field_name, field_value|
            result[field_name] = type_to_ruby(field_value)
        end
        result
    elsif value.kind_of?(Symbol)
        value.to_s
    elsif value.respond_to?(:to_str)
        value.to_str
    elsif value.kind_of?(Typelib::ArrayType) || value.kind_of?(Typelib::ContainerType)
        value.raw_each.map(&method(:type_to_ruby))
    elsif value == nil
        nil
    elsif value.respond_to?(:to_a)
        value.to_a.each do |v|
            type_to_ruby(v)
        end
    elsif value.kind_of?(Typelib::Type)
        Typelib.to_ruby(value)
    else
        value
    end
end

def pc(value)
    if value.respond_to?(:raw_each_field)
        value.raw_each_field do |k,v|
            puts "#{k} : "
            pc(v)
        end
    elsif value.respond_to?(:to_a)
        puts "- #{value.to_a}"
    else
        puts "   #{value}"
    end
end

Orocos.run 'type_to_vector::BaseTask' => 'task' do |p|

    pc1 = Types::TypeToVector::PortConfig.new
    pc1.portname = "rbs1"
    pc1.type = "/base/samples/RigidBodyState"
    pc1.slice = "position"
    pc1.vectorIdx = 2
    pc1.period = 0.3
    pc1.useTimeNow = false
    pc1.apply_changes_from_converted_types

    port_config = Hash.new
    port_config["portname"] = "rbs1"
    port_config["type"] = "/base/samples/RigidBodyState"
    port_config["slice"] = "orientation"
    port_config["vectorIdx"] = 0
    port_config["period"] = 0.1
    port_config["useTimeNow"] = false
    
    pp port_config
    puts
    pp Typelib.from_ruby(port_config, Orocos.registry.get("/type_to_vector/PortConfig"))
    puts
    pp type_to_ruby(pc1)

    puts "------------- 2 ---------------------"

    type2 = Types::Base::Pose.new
    type2.position = Eigen::Vector3.new(0.0,0.0,0.0)
    type2.orientation = Eigen::Quaternion.new(0.0,1.0,0.0,0.0)

    type2.apply_changes_from_converted_types
    
    pp type_to_ruby(type2)

    puts "---------------- 3 -----------------------"

    type3 = Types::Base::VectorXd.new
    type3.from_a [0.1, 2.2, -12.7]

    pp type3
    puts

    data = { "data" => [0.2, -3.3, 111.2] }

    pp type_to_ruby(type3)
    puts
    val = Typelib.from_ruby(data, Orocos.registry.get("/wrappers/VectorXd"))
    pp val
    puts
    pp type_to_ruby(val)

    puts
    pp type_to_ruby(nil)
   
end

