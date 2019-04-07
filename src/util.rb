module Util

  # TODO use native Ruby logger instead
  def log_info(message)
    puts "\nINFO: " + message + "\n\n"
    message
  end

  class JsonWebToken
    JWT_SECRET_PATH = Dir.pwd

    def self.encode(payload, expiration)
      payload[:exp] = expiration
      JWT.encode(payload, File.open(File.join(CERT_PATH, "localhost.key")).read)
    end

    def self.decode(token)
      return JWT.decode(token, File.open(File.join(CERT_PATH, "localhost.key")).read)[0]
    rescue
      'FAILED'
    end
  end

end