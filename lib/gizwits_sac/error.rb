# GizwitsSac = Gizwits Snoti API Client
module GizwitsSac
	class LoginError < SocketError	
	end

	class ConnTimeoutError < SocketError	
	end

	class ReadTimeoutError < SocketError
	end

	class WriteTimeoutError < SocketError
	end

	class ConnFailedError < SocketError
	end
end