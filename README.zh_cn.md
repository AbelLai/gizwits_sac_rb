# GizwitsSac-rb

GizwitsSac其实是Gizwits Snoti API Client的缩写，一个Ruby版本。


## 安装

往你的Gemfile加入以下这行:
```ruby
gem 'gizwits_sac', git: "git@github.com:AbelLai/gizwits_sac_rb.git"
```

## 用法
### 1. GizwitsSac::SnotiClient
使用GizwitsSac::SnotiClient，SnotiClient会帮你处理连接的部分以及心跳部分，你只用关心相关事件以及往连接塞你需要发送的远程控制命令。

例子：
```ruby
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
GizwitsSac封装了一个SnotiSocket，你可以基于SnotiSocket实现自己的client.

例子：
```ruby
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





