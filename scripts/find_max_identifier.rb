#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

# Finds the maximum identifier value in the geodetic registry
class MaxIdentifierFinder
  attr_reader :max_identifier, :max_identifier_file

  def initialize(registry_path)
    @registry_path = registry_path
    @max_identifier = 0
    @max_identifier_file = nil
    @stats = {
      files_processed: 0,
      files_with_identifiers: 0,
      invalid_identifiers: []
    }
  end

  def find_max
    puts "🔍 Scanning for YAML files in #{@registry_path}..."
    all_files = Dir.glob(File.join(@registry_path, "**", "*.yaml"))

    # Exclude proposals directory
    yaml_files = all_files.reject { |f| f.include?("/proposals/") }

    puts "📄 Found #{yaml_files.size} YAML files (excluded #{all_files.size - yaml_files.size} from proposals)"
    puts ""

    yaml_files.each_with_index do |file, idx|
      process_file(file)
      print "\r⏳ Processing: #{idx + 1}/#{yaml_files.size} files" if (idx + 1) % 10 == 0
    end

    puts "\n"
    print_results
  end

  def process_file(file)
    @stats[:files_processed] += 1

    # Read raw YAML content
    content = File.read(file)

    # Try safe_load first for most files
    begin
      data = YAML.safe_load(content, permitted_classes: [], aliases: true)
    rescue StandardError
      # If safe_load fails, use unsafe load but only extract identifier
      begin
        data = YAML.unsafe_load(content)
      rescue StandardError => e
        # Skip files that can't be loaded at all
        return
      end
    end

    return unless data.is_a?(Hash)

    # Extract item identifier (data.identifier)
    identifier = data.dig("data", "identifier")
    return if identifier.nil?

    @stats[:files_with_identifiers] += 1

    # Validate identifier
    id_num = identifier.to_i

    if id_num <= 0
      @stats[:invalid_identifiers] << { file: file, identifier: identifier }
      return
    end

    # Update max if this is larger
    if id_num > @max_identifier
      @max_identifier = id_num
      @max_identifier_file = file
    end
  end

  def print_results
    puts "=" * 60
    puts "📊 IDENTIFIER SCAN RESULTS"
    puts "=" * 60
    puts "Files processed:           #{@stats[:files_processed]}"
    puts "Files with identifiers:    #{@stats[:files_with_identifiers]}"
    puts "Invalid identifiers found: #{@stats[:invalid_identifiers].size}"
    puts ""

    if @stats[:invalid_identifiers].any?
      puts "⚠️  Invalid identifiers (must be positive integers):"
      @stats[:invalid_identifiers].each do |item|
        puts "  #{item[:identifier].inspect} in #{item[:file]}"
      end
      puts ""
    end

    puts "🎯 Maximum identifier found: #{@max_identifier}"
    if @max_identifier_file
      puts "   Located in: #{@max_identifier_file}"
    end
    puts "=" * 60
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  registry_path = ARGV[0] || "gr-registry"

  unless Dir.exist?(registry_path)
    puts "❌ Error: Registry path '#{registry_path}' does not exist"
    puts ""
    puts "Usage: #{$PROGRAM_NAME} [registry_path]"
    puts "  registry_path: Path to gr-registry directory (default: gr-registry)"
    exit 1
  end

  puts ""
  puts "╔════════════════════════════════════════════════════════════╗"
  puts "║         Max Identifier Finder for Geodetic Registry        ║"
  puts "╚════════════════════════════════════════════════════════════╝"
  puts ""

  finder = MaxIdentifierFinder.new(registry_path)
  finder.find_max

  puts ""
  puts "✅ Maximum identifier: #{finder.max_identifier}"
  puts ""

  # Exit with the max identifier value for scripting
  exit finder.max_identifier
end