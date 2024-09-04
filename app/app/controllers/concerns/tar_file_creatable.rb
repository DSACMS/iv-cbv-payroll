require "zlib"
require "rubygems/package"
require "tempfile"

module TarFileCreatable
  def create_tar_file(file_data)
    temp_file = Tempfile.new([ SecureRandom.uuid, ".tar" ])
    temp_file.binmode

    Gem::Package::TarWriter.new(temp_file) do |tar|
      file_data.each do |file_info|
        if file_info[:path]
          # Use existing file path
          path = file_info[:path]
          if File.exist?(path)
            mode = File.stat(path).mode
            content = File.binread(path)
            name = File.basename(path)
            size = content.size

            tar.add_file_simple(name, mode, size) do |io|
              io.write(content)
            end
          else
            Rails.logger.warn("File not found: #{path}")
          end
        else
          # Create temporary file from content
          Tempfile.create([ File.basename(file_info[:name], ".*"), File.extname(file_info[:name]) ]) do |file|
            file.binmode
            file.write(file_info[:content])
            file.flush

            mode = File.stat(file.path).mode
            size = file.size

            tar.add_file_simple(file_info[:name], mode, size) do |io|
              io.write(File.binread(file.path))
            end
          end
        end
      end
    end

    temp_file
  end

  def untar_file(tar_path, destination)
    Gem::Package::TarReader.new(File.open(tar_path, "rb")) do |tar|
      tar.each do |entry|
        file_path = File.join(destination, entry.full_name)
        if entry.directory?
          FileUtils.mkdir_p(file_path)
        else
          FileUtils.mkdir_p(File.dirname(file_path))
          File.open(file_path, "wb") do |file|
            file.write(entry.read)
          end
          File.chmod(entry.header.mode, file_path)
        end
      end
    end
  end
end
