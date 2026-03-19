class SftpGateway
  attr_reader :url, :user, :password, :private_key

  def initialize(options)
    @url = options[:url]
    @user = options[:user]
    @password = options[:password]
    @private_key = options[:private_key]
  end

  def upload_data(local_file, remote_file_location)
    session = Net::SSH.start(url, user, **ssh_options)
    sftp = Net::SFTP::Session.new(session)
    sftp.connect!
    sftp.upload! local_file, remote_file_location
    sftp.channel.eof!
    # https://github.com/net-ssh/net-ssh/issues/716
    sftp.close_channel
  end

  private

  def ssh_options
    {
      port: 22,
      password: password,
      key_data: private_key.present? ? [ private_key ] : nil
    }.compact
  end
end
