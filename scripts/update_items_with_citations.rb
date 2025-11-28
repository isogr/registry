#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "csv"
require "fileutils"

# Updates register items to use citation identifiers instead of inline citations
class CitationReferenceUpdater
  attr_reader :files_updated, :citations_replaced

  def initialize(csv_file, registry_path, backup_dir = nil)
    @csv_file = csv_file
    @registry_path = registry_path
    @backup_dir = backup_dir
    @files_updated = 0
    @citations_replaced = 0
    @title_to_id = {}
    @uuid_to_id = {}
    @errors = []
    @stats = {
      info_sources_replaced: 0,
      file_citations_replaced: 0,
      formula_citations_replaced: 0,
      files_skipped: 0
    }
  end

  def update_all
    puts "📖 Reading citation mappings from #{@csv_file}..."
    
    unless File.exist?(@csv_file)
      raise "❌ Error: CSV file '#{@csv_file}' does not exist"
    end

    load_citation_mappings

    puts "✅ Loaded #{@title_to_id.size} citation mappings"
    puts ""

    # Create backup if requested
    if @backup_dir
      create_backup
    end

    puts "🔍 Scanning for YAML files in #{@registry_path}..."
    all_files = Dir.glob(File.join(@registry_path, "**", "*.yaml"))

    # Exclude proposals and citation directory
    yaml_files = all_files.reject do |f|
      f.include?("/proposals/") || f.include?("/citation/")
    end

    puts "📄 Found #{yaml_files.size} YAML files to process"
    puts ""

    puts "🔄 Updating register items..."
    yaml_files.each_with_index do |file, idx|
      process_file(file)
      print "\r⏳ Progress: #{idx + 1}/#{yaml_files.size} files" if (idx + 1) % 10 == 0
    end

    puts "\n"
    print_statistics
    print_errors if @errors.any?
  end

  def load_citation_mappings
    csv_data = CSV.read(@csv_file, headers: true)

    csv_data.each do |row|
      identifier = row["assigned_identifier"]&.to_i
      next unless identifier && identifier > 0

      title = row["title"]
      uuid_list = row["referenced_as_uuid"]

      # Map normalized title to identifier
      if title && !title.strip.empty?
        title_key = normalize_title(title)
        @title_to_id[title_key] = identifier
      end

      # Map all UUIDs to identifier
      if uuid_list && !uuid_list.strip.empty?
        uuids = uuid_list.split(",").map(&:strip)
        uuids.each do |uuid|
          @uuid_to_id[uuid] = identifier unless uuid.empty?
        end
      end
    end
  end

  def normalize_title(title)
    title.to_s.strip.downcase.gsub(/[^\w\s]/, "").gsub(/\s+/, "_")
  end

  def create_backup
    puts "💾 Creating backup in #{@backup_dir}..."
    FileUtils.mkdir_p(@backup_dir)
    
    backup_registry = File.join(@backup_dir, "gr-registry")
    FileUtils.cp_r(@registry_path, backup_registry)
    
    puts "✅ Backup created"
    puts ""
  end

  def process_file(file)
    # Read raw YAML content
    content = File.read(file)

    # Try safe_load first
    begin
      data = YAML.safe_load(content, permitted_classes: [], aliases: true)
    rescue StandardError
      begin
        data = YAML.unsafe_load(content)
      rescue StandardError => e
        @stats[:files_skipped] += 1
        @errors << { file: file, error: "Failed to load YAML: #{e.message}" }
        return
      end
    end

    return unless data.is_a?(Hash)
    
    modified = false

    # Update informationSources
    if data.dig("data", "informationSources").is_a?(Array)
      sources = data["data"]["informationSources"]
      new_sources = sources.map do |source|
        if source.is_a?(Hash)
          citation_id = find_citation_id(source, file)
          if citation_id
            @stats[:info_sources_replaced] += 1
            @citations_replaced += 1
            modified = true
            citation_id
          else
            source
          end
        else
          source
        end
      end
      data["data"]["informationSources"] = new_sources if modified
    end

    # Update fileCitation in parameters
    if data.dig("data", "parameters").is_a?(Array)
      params = data["data"]["parameters"]
      params.each do |param|
        next unless param.is_a?(Hash)
        
        if param["fileCitation"].is_a?(Hash)
          citation_id = find_citation_id(param["fileCitation"], file)
          if citation_id
            param["fileCitation"] = citation_id
            @stats[:file_citations_replaced] += 1
            @citations_replaced += 1
            modified = true
          end
        end
      end
    end

    # Update formulaCitation
    if data.dig("data", "formulaCitation").is_a?(Hash)
      formula_citation = data["data"]["formulaCitation"]
      citation_id = find_citation_id(formula_citation, file)
      if citation_id
        # Formula citations should be arrays to support multiple citations
        data["data"]["formulaCitation"] = [citation_id]
        @stats[:formula_citations_replaced] += 1
        @citations_replaced += 1
        modified = true
      end
    end

    # Write back if modified
    if modified
      File.write(file, YAML.dump(data))
      @files_updated += 1
    end
  rescue StandardError => e
    @errors << { file: file, error: "Failed to process: #{e.message}" }
    @stats[:files_skipped] += 1
  end

  def find_citation_id(citation_hash, source_file)
    return nil unless citation_hash.is_a?(Hash)

    # Try UUID lookup first (most reliable)
    if citation_hash["uuid"]
      uuid = citation_hash["uuid"].to_s.strip
      citation_id = @uuid_to_id[uuid]
      return citation_id if citation_id
    end

    # Fallback to title lookup
    if citation_hash["title"]
      title_key = normalize_title(citation_hash["title"])
      citation_id = @title_to_id[title_key]
      return citation_id if citation_id
    end

    # If we can't find a mapping, record it as an error
    @errors << {
      file: source_file,
      error: "No citation mapping found for: #{citation_hash['title']}"
    }

    nil
  end

  def print_statistics
    puts ""
    puts "=" * 60
    puts "📊 UPDATE STATISTICS"
    puts "=" * 60
    puts "Files updated:                 #{@files_updated}"
    puts "Files skipped:                 #{@stats[:files_skipped]}"
    puts "Total citations replaced:      #{@citations_replaced}"
    puts "  - informationSources:        #{@stats[:info_sources_replaced]}"
    puts "  - fileCitation:              #{@stats[:file_citations_replaced]}"
    puts "  - formulaCitation:           #{@stats[:formula_citations_replaced]}"
    puts "Errors encountered:            #{@errors.size}"
    puts "=" * 60
  end

  def print_errors
    puts ""
    puts "⚠️  ERRORS ENCOUNTERED"
    puts "=" * 60
    
    # Group errors by type
    error_groups = @errors.group_by { |e| e[:error].split(":").first }
    
    error_groups.each do |error_type, errors|
      puts ""
      puts "#{error_type} (#{errors.size} occurrences):"
      errors.first(5).each do |error|
        puts "  - #{error[:file]}"
        puts "    #{error[:error]}"
      end
      puts "  ... and #{errors.size - 5} more" if errors.size > 5
    end
    
    puts ""
    puts "=" * 60
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  csv_file = ARGV[0] || "citations.csv"
  registry_path = ARGV[1] || "gr-registry"
  backup_dir = ARGV[2]

  unless File.exist?(csv_file)
    puts "❌ Error: CSV file '#{csv_file}' does not exist"
    puts ""
    puts "Usage: #{$PROGRAM_NAME} [csv_file] [registry_path] [backup_dir]"
    puts "  csv_file:      Path to citations CSV file (default: citations.csv)"
    puts "  registry_path: Path to gr-registry directory (default: gr-registry)"
    puts "  backup_dir:    Optional backup directory (recommended for safety)"
    exit 1
  end

  unless Dir.exist?(registry_path)
    puts "❌ Error: Registry path '#{registry_path}' does not exist"
    exit 1
  end

  # Check if CSV has assigned_identifier column
  headers = CSV.read(csv_file, headers: true).headers
  unless headers.include?("assigned_identifier")
    puts "❌ Error: CSV file must have 'assigned_identifier' column"
    puts "   Run create_citation_items.rb first to assign identifiers"
    exit 1
  end

  puts ""
  puts "╔════════════════════════════════════════════════════════════╗"
  puts "║    Citation Reference Updater for Geodetic Registry        ║"
  puts "╚════════════════════════════════════════════════════════════╝"
  puts ""

  if backup_dir.nil?
    puts "⚠️  WARNING: No backup directory specified!"
    puts "   This script will modify registry files in place."
    print "   Continue? (y/N): "
    response = gets.chomp.downcase
    unless response == "y" || response == "yes"
      puts "Aborted."
      exit 0
    end
    puts ""
  end

  updater = CitationReferenceUpdater.new(csv_file, registry_path, backup_dir)
  updater.update_all

  puts ""
  puts "🎉 Citation reference update complete!"
  puts ""
end