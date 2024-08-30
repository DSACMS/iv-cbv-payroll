require "zlib"
require "rubygems/package"

module TarFileCreatable
  def create_tar_file(tar_file_path, file_paths)
    File.open(tar_file_path, "wb") do |file|
      Gem::Package::TarWriter.new(file) do |tar|
        file_paths.each do |path|
          if File.exist?(path)
            mode = File.stat(path).mode
            content = File.binread(path)

            tar.add_file_simple(File.basename(path), mode, content.size) do |io|
              io.write(content)
            end
          else
            Rails.logger.warn("File not found: #{path}")
          end
        end
      end
    end
    tar_file_path
  end

  def untar_file(tar_content, destination)
    StringIO.open(tar_content) do |io|
      Gem::Package::TarReader.new(io) do |tar|
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
end
