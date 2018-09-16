require "optparse"
require "erb"
require "json"
require "ipaddress"
require "pty"
require "expect"

Signal.trap("INT") { exit }

# usage: 
#   sudo ruby ./conbu-sw-detchup.rb -c [config] -t [template] -s [switch] -C [console device]
# example:
#   sudo ruby ./conbu-sw-detchup.rb -c config.json -t template.txt -s SW102 -C /dev/ttyUSB0

params = ARGV.getopts("c:t:s:C:")
if params.values.include?(nil)
  STDERR.puts "ERROR: argument is missing"
  exit 1
end

p params

config_file = params["c"]
$config = JSON.load(File.open(config_file).read)
template_file = params["t"]
$template = File.open(template_file).read
$target_sw = params["s"]
$serialdev = params["C"]


common = $config["common"]
my = $config[$target_sw]
if my.nil?
  STDERR.puts "ERROR: target switch not found #{$target_sw}"
  exit 1
end


# prepare common
## acl-cloud-prefix => acl-cloud-network, acl-cloud-mask
acl_cloud_prefix = common["acl-cloud-prefix"]
if acl_cloud_prefix
  prefix = IPAddress(acl_cloud_prefix)
  maskaddr = IPAddress(prefix.netmask)
  filtermask_i = (maskaddr.to_i ^ 0xffffffff)
  filtermask = IPAddress(filtermask_i)

  common["acl-cloud-network"] = prefix.network.to_s
  common["acl-cloud-mask"] = filtermask.to_s
end

# prepare per-sw
## hostname
my["hostname"] = $target_sw
## mgmt-addr
mgmt_addr = my["mgmt-addr"]
if mgmt_addr
  prefix = IPAddress(mgmt_addr)
  my["mgmt-addr-host"] = prefix.address
  my["mgmt-addr-netmask"] = prefix.netmask
end

## port => downlink-port-head, downlink-port-tail, uplink-port
port = my["port"] || 24
my["uplink-port"] = port
my["downlink-port-tail"] = port - 1
my["downlink-port-head"] = port - 3 # only 3 downlink port

puts "========== COMMON CONFIG =========="
puts JSON.pretty_generate(common)
puts "======== SWITCH (#{$target_sw}) specific ========"
puts JSON.pretty_generate(my)
puts "=" * 40


# generate config
erb = ERB.new($template, nil, "-")
config_text = erb.result(binding)
config_lines = config_text.split("\n").map{|line|
  case line.strip
  when /^!$/
    "exit"
  when /^$/
    nil
  else
    line.strip
  end
}.compact
puts "========== GENERATED CONFIG =========="
puts config_lines.join("\n")
puts "======================================"

puts "press any key to continue, or ^C to quit"
gets

cmd = "cu -l #{$serialdev} -s 9600"
puts cmd
PTY.spawn(cmd) do |rf, wf, pid|
  wf.sync = true
  $expect_verbose = true

  wf.puts ""
  wf.puts ""
  wf.puts ""

  config_ok = false
  fail_cnt = 0
  while !config_ok
    rf.expect(/(\(config\)#|#|>)$/) do |pattern|
      puts "patt => #{pattern}"
      unless pattern
        fail_cnt += 1
        next if fail_cnt < 10
        exit
      end
      case pattern[-1]
      when ">"
        wf.puts "enable"
        sleep 0.5
      when "#"
        wf.puts "configure terminal"
        sleep 0.5
      when "(config)#"
        config_ok = true
      else
        puts "WTF"
        exit 10
      end
    end
  end

  while line = config_lines.shift
    rf.expect(/(#)$/) do
      puts "CONFIG => #{line}"
      wf.puts(line)
    end
    sleep 0.5
  end

  rf.expect(/(#)$/) do
    wf.puts "exit"
  end
  rf.expect(/(#)$/) do
    wf.puts "exit"
  end

  wf.close
  rf.close
end

puts ""
puts ""
puts "done"
puts "!!!!! don't forget to WRITE MEMORY !!!!"
