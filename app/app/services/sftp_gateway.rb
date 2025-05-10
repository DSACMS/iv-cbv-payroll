class SftpGateway
  attr_reader :url, :user, :password
  def initialize(options)
    @url = options[:url]
    @user = options[:user]
    @password = options[:password]
  end

  def upload_data(local_data, remote_file_location)
    session = Net::SSH.start(url, user, password: password, port: 22)
    sftp = Net::SFTP::Session.new(session)
    sftp.connect!
    sftp.upload! local_data, remote_file_location
    sftp.channel.eof!
    # https://github.com/net-ssh/net-ssh/issues/716
    sftp.close_channel
  end
end
