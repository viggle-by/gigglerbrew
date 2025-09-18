require 'json'
require 'fileutils'
require 'open-uri'
require 'zlib'
require 'rubygems/package'

module Giggler
  FORMULA_DIR = File.expand_path('../../Formula', __FILE__)
  PACKAGES_DIR = File.expand_path('../../packages', __FILE__)
  REGISTRY_FILE = File.expand_path('../../registry.json', __FILE__)

  # Convert package name like "python@2" to class name like "PythonAT2"
  def self.camelize(str)
    # Replace '@' with 'at', then snake_case to CamelCase
    str = str.gsub('@', 'at')
    str.split('_').map(&:capitalize).join.sub('At', 'AT')
  end

  # Load formula class from Formula directory
  def self.load_formula(name)
    formula_file = File.join(FORMULA_DIR, "#{name}.rb")
    unless File.exist?(formula_file)
      raise "Formula file not found: #{formula_file}"
    end

    require formula_file

    class_name = camelize(name)
    klass = Object.const_get(class_name)
    klass.new
  rescue NameError
    raise "Formula class '#{class_name}' not found in #{formula_file}"
  end

  # Extract .tar.gz or .tar.xz archives
  def self.extract_archive(file_path, dest_dir)
    FileUtils.mkdir_p(dest_dir)

    case file_path
    when /\.tar\.gz$/, /\.tgz$/
      extract_tar_gz(file_path, dest_dir)
    when /\.tar\.xz$/
      extract_tar_xz(file_path, dest_dir)
    else
      raise "Unsupported archive format: #{file_path}"
    end
  end

  def self.extract_tar_gz(file_path, dest_dir)
    puts "Extracting #{file_path} to #{dest_dir} (tar.gz)"
    File.open(file_path, 'rb') do |file|
      Zlib::GzipReader.wrap(file) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each do |entry|
            dest_file = File.join(dest_dir, entry.full_name)
            if entry.directory?
              FileUtils.mkdir_p(dest_file)
            else
              FileUtils.mkdir_p(File.dirname(dest_file))
              File.open(dest_file, "wb") { |f| f.write(entry.read) }
            end
          end
        end
      end
    end
  end

  def self.extract_tar_xz(file_path, dest_dir)
    puts "Extracting #{file_path} to #{dest_dir} (tar.xz)"
    # Use system tar with xz support for simplicity and reliability
    system("tar", "-xJf", file_path, "-C", dest_dir) or
      raise "Failed to extract #{file_path}"
  end

  # Download file to target path
  def self.download(url, target_path)
    puts "Downloading #{url}..."
    URI.open(url) do |remote_file|
      File.open(target_path, "wb") do |local_file|
        IO.copy_stream(remote_file, local_file)
      end
    end
  end

  # Install a package by name (e.g. python@2)
  def self.install(name)
    formula = load_formula(name)

    # Create package directory
    pkg_dir = File.join(PACKAGES_DIR, name)
    if Dir.exist?(pkg_dir)
      puts "#{name} already installed at #{pkg_dir}"
      return
    end
    FileUtils.mkdir_p(pkg_dir)

    # Download source archive
    source_url = formula.url
    archive_filename = File.basename(source_url)
    archive_path = File.join(pkg_dir, archive_filename)

    download(source_url, archive_path)

    # Verify checksum if available
    if formula.respond_to?(:sha256) && formula.sha256
      require 'digest'
      actual_sha = Digest::SHA256.file(archive_path).hexdigest
      expected_sha = formula.sha256.downcase
      if actual_sha != expected_sha
        File.delete(archive_path)
        raise "SHA256 mismatch: expected #{expected_sha}, got #{actual_sha}"
      end
      puts "SHA256 checksum verified."
    end

    # Extract archive
    extract_dir = File.join(pkg_dir, 'src')
    extract_archive(archive_path, extract_dir)

    # Run install instructions if defined
    if formula.respond_to?(:install)
      puts "Running install steps for #{name}..."
      Dir.chdir(extract_dir) do
        formula.install
      end
    end

    puts "#{name} installed successfully to #{pkg_dir}"
  end
end
