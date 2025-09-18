require 'json'
require 'open-uri'
require 'fileutils'
require 'digest'

module Giggler
  PREFIX = "/opt/giggler"
  REGISTRY_URL = "https://raw.githubusercontent.com/yourusername/giggler-registry/main/registry.json"
  REGISTRY_PATH = "#{PREFIX}/registry.json"
  INSTALL_DIR = "#{PREFIX}/Cellar"

  class << self
    def install(package)
      registry = load_registry
      formula = registry[package]

      unless formula
        puts "Package '#{package}' not found."
        return
      end

      url = formula["url"]
      sha256 = formula["sha256"]
      filename = File.basename(url)
      download_path = "/tmp/#{filename}"

      puts "Downloading #{package}..."
      URI.open(url) do |remote|
        File.open(download_path, "wb") { |file| file.write(remote.read) }
      end

      puts "Verifying checksum..."
      actual_sha256 = Digest::SHA256.file(download_path).hexdigest
      if actual_sha256 != sha256
        puts "SHA256 mismatch! Aborting."
        return
      end

      puts "Extracting..."
      extract_path = "#{INSTALL_DIR}/#{package}"
      FileUtils.mkdir_p(extract_path)

      case filename
      when /\.tar\.xz$/
        system "tar", "-xf", download_path, "-C", extract_path, "--strip-components=1"
      when /\.tar\.gz$/
        system "tar", "-xzf", download_path, "-C", extract_path, "--strip-components=1"
      else
        puts "Unsupported archive format: #{filename}"
        return
      end

      puts "#{package} installed to #{extract_path}"
    end

    def remove(package)
      path = "#{INSTALL_DIR}/#{package}"
      if Dir.exist?(path)
        FileUtils.rm_rf(path)
        puts "Removed #{package}."
      else
        puts "Package not installed: #{package}"
      end
    end

    def list
      puts "Installed packages:"
      Dir.children(INSTALL_DIR).each do |pkg|
        puts "- #{pkg}"
      end
    rescue
      puts "No packages installed."
    end

    def info(package)
      registry = load_registry
      if (formula = registry[package])
        puts "Name: #{package}"
        puts "Description: #{formula['desc']}"
        puts "Homepage: #{formula['homepage']}"
        puts "URL: #{formula['url']}"
        puts "SHA256: #{formula['sha256']}"
      else
        puts "Package '#{package}' not found."
      end
    end

    def search(term)
      registry = load_registry
      matches = registry.keys.select { |name| name.include?(term) }
      if matches.empty?
        puts "No packages found for: #{term}"
      else
        puts "Matches:"
        matches.each { |name| puts "- #{name}" }
      end
    end

    def update_registry
      puts "Updating registry..."
      content = URI.open(REGISTRY_URL).read
      FileUtils.mkdir_p(PREFIX)
      File.write(REGISTRY_PATH, content)
      puts "Registry updated."
    rescue => e
      puts "Failed to update registry: #{e.message}"
    end

    def package_count
      registry = load_registry
      registry.size
    rescue
      0
    end

    def help
      puts <<~HELP
        Gigglercraft - Commands:

        install <package>     Install a package
        remove <package>      Remove a package
        list                  List installed packages
        info <package>        Show info about a package
        search <term>         Search for packages
        update                Update the package registry
        count                 Count packages in the registry
        help                  Show this help message

        Flags:
        --version             Show Gigglercraft version
        --prefix              Show installation prefix
      HELP
    end

    def prefix
      PREFIX
    end

    def version
      "0.1.0"
    end

    private

    def load_registry
      unless File.exist?(REGISTRY_PATH)
        puts "Registry not found. Run `giggler update` first."
        exit 1
      end

      JSON.parse(File.read(REGISTRY_PATH))
    end
  end
end