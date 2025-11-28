#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "csv"
require "fileutils"
require "securerandom"
require_relative "citation"

# Creates citation register items from extracted citations
class CitationItemCreator
  attr_reader :citations_created, :start_identifier

  def initialize(csv_file, registry_path, start_identifier)
    @csv_file = csv_file
    @registry_path = registry_path
    @start_identifier = start_identifier
    @citations_created = 0
    @citation_id_map = {}
    @citation_uuid_map = {}
  end

  def create_all
    puts "📖 Reading citations from #{@csv_file}..."
    
    unless File.exist?(@csv_file)
      raise "❌ Error: CSV file '#{@csv_file}' does not exist"
    end

    # Read CSV and parse citations
    citations = read_citations_from_csv

    puts "✅ Found #{citations.size} citations to create"
    puts ""

    # Create citation directory if it doesn't exist
    citation_dir = File.join(@registry_path, "citation")
    FileUtils.mkdir_p(citation_dir)
    puts "📁 Citation directory: #{citation_dir}"
    puts ""

    # Create citation items
    puts "🔨 Creating citation items..."
    current_identifier = @start_identifier

    citations.each_with_index do |citation_data, idx|
      citation_uuid = create_citation_item(citation_data, current_identifier, citation_dir)
      
      # Track mapping from CSV id to register identifier and UUID
      @citation_id_map[citation_data[:csv_id]] = current_identifier
      @citation_uuid_map[citation_data[:csv_id]] = citation_uuid
      
      current_identifier += 1
      @citations_created += 1

      print "\r⏳ Progress: #{idx + 1}/#{citations.size} citations" if (idx + 1) % 10 == 0
    end

    puts "\n"

    # Update CSV with assigned identifiers
    update_csv_with_identifiers

    print_statistics
  end

  def read_citations_from_csv
    citations = []
    csv_data = CSV.read(@csv_file, headers: true)

    csv_data.each do |row|
      citation = {
        csv_id: row["id"].to_i,
        title: row["title"],
        author: row["author"],
        publisher: row["publisher"],
        edition: row["edition"],
        edition_date: row["editionDate"],
        revision_date: row["revisionDate"],
        series_name: row["seriesName"],
        series_issue_id: row["seriesIssueID"],
        series_page: row["seriesPage"],
        isbn: row["isbn"],
        issn: row["issn"],
        other_details: row["otherDetails"],
        uuid: row["uuid"],
        variants: row["variants"]
      }

      # Remove nil/empty values
      citation.delete_if { |k, v| v.nil? || v.to_s.strip.empty? }

      citations << citation
    end

    citations
  end

  def create_citation_item(citation_data, identifier, citation_dir)
    # Generate UUID for this citation item
    item_uuid = SecureRandom.uuid

    # Build citation item structure
    item = {
      "id" => item_uuid,
      "dateAccepted" => Time.now.utc.strftime("%Y-%m-%d"),
      "status" => "valid",
      "data" => {
        "identifier" => identifier,
        "name" => citation_data[:title],
        "title" => citation_data[:title]
      }
    }

    # Add optional fields to data section
    optional_fields = {
      author: "author",
      publisher: "publisher",
      edition: "edition",
      edition_date: "editionDate",
      revision_date: "revisionDate",
      series_name: "seriesName",
      series_issue_id: "seriesIssueID",
      series_page: "seriesPage",
      isbn: "isbn",
      issn: "issn",
      other_details: "otherDetails"
    }

    optional_fields.each do |key, yaml_key|
      value = citation_data[key]
      item["data"][yaml_key] = value if value && !value.to_s.strip.empty?
    end

    # Add original UUID if present (for traceability)
    if citation_data[:uuid] && !citation_data[:uuid].to_s.strip.empty?
      item["data"]["originalUuid"] = citation_data[:uuid]
    end

    # Add variants information if present
    if citation_data[:variants] && !citation_data[:variants].to_s.strip.empty?
      item["data"]["remarks"] = "This citation has variants: #{citation_data[:variants]}"
    end

    # Write to YAML file
    file_path = File.join(citation_dir, "#{item_uuid}.yaml")
    File.write(file_path, YAML.dump(item))

    item_uuid
  end

  def update_csv_with_identifiers
    puts "📝 Updating CSV with assigned identifiers..."

    # Read current CSV
    csv_data = CSV.read(@csv_file, headers: true)
    headers = csv_data.headers

    # Add new columns if not present
    unless headers.include?("assigned_identifier")
      headers << "assigned_identifier"
    end
    unless headers.include?("citation_item_uuid")
      headers << "citation_item_uuid"
    end

    # Create new CSV with updated data
    temp_file = "#{@csv_file}.tmp"
    CSV.open(temp_file, "w") do |csv|
      csv << headers

      csv_data.each do |row|
        csv_id = row["id"].to_i
        new_row = row.to_h

        # Add assigned identifier and UUID
        new_row["assigned_identifier"] = @citation_id_map[csv_id]
        new_row["citation_item_uuid"] = @citation_uuid_map[csv_id]

        csv << headers.map { |h| new_row[h] }
      end
    end

    # Replace original CSV with updated one
    FileUtils.mv(temp_file, @csv_file)
    puts "✅ CSV updated with assigned identifiers"
  end

  def print_statistics
    puts ""
    puts "=" * 60
    puts "📊 CREATION STATISTICS"
    puts "=" * 60
    puts "Citations created:     #{@citations_created}"
    puts "Starting identifier:   #{@start_identifier}"
    puts "Ending identifier:     #{@start_identifier + @citations_created - 1}"
    puts "Citation directory:    #{File.join(@registry_path, 'citation')}"
    puts "=" * 60
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  csv_file = ARGV[0] || "citations.csv"
  registry_path = ARGV[1] || "gr-registry"
  start_identifier = ARGV[2]&.to_i

  unless File.exist?(csv_file)
    puts "❌ Error: CSV file '#{csv_file}' does not exist"
    puts ""
    puts "Usage: #{$PROGRAM_NAME} [csv_file] [registry_path] [start_identifier]"
    puts "  csv_file:         Path to citations CSV file (default: citations.csv)"
    puts "  registry_path:    Path to gr-registry directory (default: gr-registry)"
    puts "  start_identifier: Starting identifier (if not provided, will find max + 1)"
    exit 1
  end

  unless Dir.exist?(registry_path)
    puts "❌ Error: Registry path '#{registry_path}' does not exist"
    exit 1
  end

  # If start_identifier not provided, find max identifier
  unless start_identifier
    puts "🔍 Finding maximum identifier in registry..."
    require_relative "find_max_identifier"
    finder = MaxIdentifierFinder.new(registry_path)
    finder.find_max
    start_identifier = finder.max_identifier + 1
    puts "   Will start from identifier: #{start_identifier}"
    puts ""
  end

  puts ""
  puts "╔════════════════════════════════════════════════════════════╗"
  puts "║       Citation Item Creator for Geodetic Registry          ║"
  puts "╚════════════════════════════════════════════════════════════╝"
  puts ""

  creator = CitationItemCreator.new(csv_file, registry_path, start_identifier)
  creator.create_all

  puts ""
  puts "🎉 Citation item creation complete!"
  puts ""
end