# GizwitsSac-rb

GizwitsSac is short for Gizwits Snoti API Client, and GizwitsSac-rb just a Ruby version, which I hope it can help you more easily to connect to [Gizwits Snoti API](http://docs.gizwits.com/zh-cn/Cloud/NotificationAPI.html).

### [中文说明](https://github.com/AbelLai/gizwits_sac_rb/blob/master/README.zh_cn.md)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gizwits_sac'
```

## Usage
### 1. GizwitsSac::SnotiClient
Simply you can just use GizwitsSac::SnotiClient, and focus on the event via callback as the example below. (**GizwitsSac::SnotiClient will handle heartbeat for you in ervery seconds you set.**)

```ruby
require "gizwits_sac"

event_push_handler = Proc.new do |event_push_data|
	# Here it just care the event *device_status_raw*.
	if event_push_data["event_type"] == "device_status_raw"
		puts "event_push_data =====> #{event_push_data}"
	end
end
remote_ctrl_handler = Proc.new do
	get_your_remote_ctrl_req
end
remote_ctrl_res_handler = Proc.new do |r_ctrl_res_data|
	puts "r_ctrl_res_data =====> #{r_ctrl_res_data}"
end

client = GizwitsSac::SnotiClient.new({
	event_push: event_push_handler,
	remote_ctrl: remote_ctrl_handler,
	remote_ctrl_res: remote_ctrl_res_handler,
	heartbeat_interval: 60, # default value is 5
	retry_count: 10, # default value is 5
	logger: Logger.new(STDOUT),
	host: "snoti.gizwits.com",
	port: "2017",
	connect_timeout: 3, # default value is 3 seconds
	read_timeout: 3, # default value is 3 seconds
	write_timeout: 3, # default value is 3 seconds
	prefetch_count: 50, # default value is 50
	auth_data: [
		{
			product_key: "your_product_key_here",
			auth_id: "your_auth_id_here",
			auth_secret: "your_auth_secret_here",
			subkey: "your_subkey_here",
			events: ['event_you_care_about', 'event_you_care_about', ...]
		}
	]
})

client.start
```

### 2. GizwitsSac::SnotiSocket
Another way, you can use GizwitsSac::SnotiSocket, and build a client as you like. Here is a very very simple example as below.
```ruby
require "gizwits_sac"

socket = GizwitsocketC::SnotiSocket.new({
	host: "snoti.gizwits.com",
	port: "2017",
	connect_timeout: 3, # default value is 3 seconds
	read_timeout: 3, # default value is 3 seconds
	write_timeout: 3, # default value is 3 seconds
	prefetch_count: 50, # default value is 50
	auth_data: [
		{
			product_key: "your_product_key_here",
			auth_id: "your_auth_id_here",
			auth_secret: "your_auth_secret_here",
			subkey: "your_subkey_here",
			events: ['event_you_care_about', 'event_you_care_about', ...]
		}
	]
})

socket.connect
if socket.login_ok?
	puts "login ok"	
	loop do
		data = socket.read
		puts data
		sleep 2
	end
else
	puts "login failed"
end
```
## TODO: Unit Test





