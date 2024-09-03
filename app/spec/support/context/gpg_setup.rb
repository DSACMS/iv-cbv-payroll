RSpec.shared_context "gpg_setup" do
  before(:all) do
    @original_gpg_home = ENV['GNUPGHOME']
    ENV['GNUPGHOME'] = Rails.root.join('tmp', 'gpghome').to_s
    FileUtils.mkdir_p(ENV['GNUPGHOME'])

    key_script = <<-SCRIPT
        %echo Generating a basic OpenPGP key
        Key-Type: RSA
        Key-Length: 2048
        Subkey-Type: RSA
        Subkey-Length: 2048
        Name-Real: Test User
        Name-Email: test@example.com
        Expire-Date: 0
        %no-protection
        %commit
        %echo done
      SCRIPT

    IO.popen('gpg --batch --generate-key', 'r+') do |io|
      io.write(key_script)
      io.close_write
      io.read
    end

    @public_key = GPGME::Key.find(:public, 'test@example.com').first.export(armor: true)

    # Verify that the key was imported successfully
    raise "Failed to import GPG key" unless @public_key
  end

  after(:all) do
    FileUtils.remove_entry ENV['GNUPGHOME'] if File.exist?(ENV['GNUPGHOME'])
    ENV['GNUPGHOME'] = @original_gpg_home
  end
end
