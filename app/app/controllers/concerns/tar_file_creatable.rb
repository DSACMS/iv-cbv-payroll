module TarFileCreatable
  extend ActiveSupport::Concern

  def create_tar_file(tar_file_path, file_paths)
    File.open(tar_file_path, "wb") do |tar|
      file_paths.each do |path|
        if File.exist?(path)
          filename = File.basename(path)
          content = File.binread(path)

          header = StringIO.new
          header.write(filename.ljust(100, "\0"))
          header.write(sprintf("%07o\0", File.stat(path).mode))
          header.write(sprintf("%07o\0", Process.uid))
          header.write(sprintf("%07o\0", Process.gid))
          header.write(sprintf("%011o\0", content.size))
          header.write(sprintf("%011o\0", File.stat(path).mtime.to_i))
          header.write("        ")
          header.write("0")
          header.write("\0" * 355)

          checksum = header.string.bytes.sum
          header.string[148, 8] = sprintf("%06o\0 ", checksum)

          tar.write(header.string)
          tar.write(content)
          tar.write("\0" * (512 - (content.size % 512))) if content.size % 512 != 0
        else
          Rails.logger.warn("File not found: #{path}")
        end
      end
      # Add two 512-byte null blocks to mark the end of the archive
      tar.write("\0" * 1024)
    end
    tar_file_path
  end

  def untar_file(tar_content, destination)
    io = StringIO.new(tar_content)

    while (header = io.read(512))
      break if header.strip.empty?  # End of archive

      filename = header[0...100].strip
      mode = header[100...108].strip.to_i(8)
      size = header[124...136].strip.to_i(8)

      file_path = File.join(destination, filename)

      if filename.end_with?("/")
        FileUtils.mkdir_p(file_path)
      else
        FileUtils.mkdir_p(File.dirname(file_path))
        File.open(file_path, "wb") do |file|
          file.write(io.read(size))
        end
        File.chmod(mode, file_path)
      end

      # Move to the next 512-byte boundary
      io.pos += (512 - (size % 512)) % 512
    end
  end
end
