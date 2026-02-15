#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "fileutils"
require "securerandom"
require "csv"
require "set"
require_relative "citation"

# Citation extractor for geodetic registry
class CitationExtractor
  attr_reader :citations, :title_groups

  def initialize(registry_path)
    @registry_path = registry_path
    @citations = []
    @title_groups = {}
    @citation_references = Hash.new { |h, k| h[k] = [] }
    @citation_uuids = Hash.new { |h, k| h[k] = [] }
    @formula_references = Hash.new { |h, k| h[k] = [] }
    @all_item_classes = Set.new
    @stats = {
      files_processed: 0,
      citations_found: 0,
      formula_citations_found: 0,
      unique_titles: 0,
      citations_with_variants: 0
    }
  end

  def extract_all
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
    group_by_title
    generate_ids
    print_statistics
  end

  def process_file(file)
    @stats[:files_processed] += 1

    # Read raw YAML content
    content = File.read(file)

    # Try safe_load first for most files
    begin
      data = YAML.safe_load(content, permitted_classes: [], aliases: true)
    rescue StandardError
      # If safe_load fails, use unsafe load but only extract citation data
      begin
        data = YAML.unsafe_load(content)
      rescue StandardError => e
        # Skip files that can't be loaded at all
        return
      end
    end

    return unless data.is_a?(Hash)

    # Extract item identifier (data.identifier) and class from file path
    item_identifier = data.dig("data", "identifier")
    item_class = extract_item_class(file)
    @all_item_classes << item_class if item_class

    extract_from_data(data, file, item_identifier, item_class)
  end

  def extract_item_class(file_path)
    # Extract item class from path like "gr-registry/coordinate-ops--conversion/..."
    # or "gr-registry/proposals/.../items/coordinate-ops--conversion/..."
    if file_path.include?("/items/")
      file_path.split("/items/")[1].split("/")[0]
    else
      parts = file_path.split("/")
      # Find the part after gr-registry that contains the class
      idx = parts.index { |p| p == "gr-registry" }
      return nil unless idx

      class_part = parts[idx + 1]
      return nil if class_part == "proposals"

      class_part
    end
  end

  def extract_from_data(data, source_file, item_identifier, item_class)
    # Extract from informationSources
    if data.dig("data", "informationSources")
      sources = data["data"]["informationSources"]
      sources.each do |source|
        add_citation(source, source_file, item_identifier, item_class) if source.is_a?(Hash)
      end
    end

    # Extract from fileCitation in parameters
    if data.dig("data", "parameters")
      params = data["data"]["parameters"]
      params.each do |param|
        next unless param.is_a?(Hash) && param["fileCitation"].is_a?(Hash)

        add_citation(param["fileCitation"], source_file, item_identifier, item_class)
      end
    end

    # Extract from formulaCitation
    if data.dig("data", "formulaCitation").is_a?(Hash)
      formula_citation = data["data"]["formulaCitation"]
      add_formula_citation(formula_citation, source_file, item_identifier, item_class)
    end
  end

  def add_citation(source_hash, source_file, item_identifier, item_class)
    return if source_hash["title"].nil? || source_hash["title"].to_s.strip.empty?

    @stats[:citations_found] += 1

    citation = Citation.new
    citation.title = source_hash["title"]
    citation.author = source_hash["author"]
    citation.publisher = source_hash["publisher"]
    citation.edition = source_hash["edition"]
    citation.edition_date = source_hash["editionDate"]
    citation.revision_date = source_hash["revisionDate"]
    citation.series_name = source_hash["seriesName"]
    citation.series_issue_id = source_hash["seriesIssueID"]
    citation.series_page = source_hash["seriesPage"]
    citation.isbn = source_hash["isbn"]
    citation.issn = source_hash["issn"]
    citation.other_details = source_hash["otherDetails"]
    citation.uuid = source_hash["uuid"]

    @citations << citation

    title_key = normalize_title(citation.title)

    # Track all UUIDs for this citation
    if citation.uuid && !citation.uuid.to_s.strip.empty?
      @citation_uuids[title_key] << citation.uuid
    end

    # Track which items reference this citation (using data.identifier)
    if item_identifier && item_class
      validate_identifier!(item_identifier, source_file)
      @citation_references[title_key] << { identifier: item_identifier, class: item_class }
    end
  end

  def add_formula_citation(source_hash, source_file, item_identifier, item_class)
    return if source_hash["title"].nil? || source_hash["title"].to_s.strip.empty?

    @stats[:formula_citations_found] += 1

    citation = Citation.new
    citation.title = source_hash["title"]
    citation.author = source_hash["author"]
    citation.publisher = source_hash["publisher"]
    citation.edition = source_hash["edition"]
    citation.edition_date = source_hash["editionDate"]
    citation.revision_date = source_hash["revisionDate"]
    citation.series_name = source_hash["seriesName"]
    citation.series_issue_id = source_hash["seriesIssueID"]
    citation.series_page = source_hash["seriesPage"]
    citation.isbn = source_hash["isbn"]
    citation.issn = source_hash["issn"]
    citation.other_details = source_hash["otherDetails"]
    citation.uuid = source_hash["uuid"]

    @citations << citation

    title_key = normalize_title(citation.title)

    # Track all UUIDs for this formula citation
    if citation.uuid && !citation.uuid.to_s.strip.empty?
      @citation_uuids[title_key] << citation.uuid
    end

    # Track formula references
    if item_identifier && item_class
      validate_identifier!(item_identifier, source_file)
      @formula_references[title_key] << { identifier: item_identifier, class: item_class }
    end
  end

  def validate_identifier!(identifier, source_file)
    return if identifier.nil?

    id_num = identifier.to_i
    return if id_num > 0

    raise "Invalid identifier #{identifier.inspect} in file #{source_file}. " \
          "Identifiers must be positive integers."
  end

  def group_by_title
    puts "🔗 Grouping citations by title..."

    @citations.each do |citation|
      title_key = normalize_title(citation.title)
      @title_groups[title_key] ||= []
      @title_groups[title_key] << citation
    end

    @stats[:unique_titles] = @title_groups.size
  end

  def generate_ids
    puts "🆔 Generating unique IDs and detecting variants..."

    @title_groups.each do |title_key, group|
      # Group by content using model equality
      content_groups = group.group_by do |citation|
        # Citations are equal if all their attributes match
        citation
      end

      if content_groups.size == 1
        # All citations with this title are identical
        citation = content_groups.values.first.first
        citation.id = generate_citation_id(title_key)
      else
        # Multiple variants exist
        @stats[:citations_with_variants] += 1

        # Create a main citation from the most complete one
        main_citation = select_most_complete(group)
        main_citation.id = generate_citation_id(title_key)

        # Add variant information
        main_citation.variants = content_groups.keys.map.with_index do |sig, idx|
          "variant-#{idx + 1}"
        end
      end
    end
  end

  def select_most_complete(citations)
    # Select citation with most non-nil fields
    citations.max_by do |c|
      [
        c.author, c.publisher, c.edition, c.edition_date,
        c.revision_date, c.series_name, c.series_issue_id,
        c.series_page, c.isbn, c.issn, c.other_details, c.uuid
      ].count { |field| field && !field.to_s.strip.empty? }
    end
  end

  def normalize_title(title)
    title.to_s.strip.downcase.gsub(/[^\w\s]/, "").gsub(/\s+/, "_")
  end

  def generate_citation_id(title_key)
    # Create a short, deterministic ID based on title
    base_id = title_key.gsub(/[^a-z0-9_]/, "")[0..50]
    "citation-#{base_id}"
  end

  def output_yaml(output_file)
    puts "\n💾 Writing citations to #{output_file}..."

    # Get unique citations (one per title)
    unique_citations = @title_groups.values.map do |group|
      group.find { |c| c.id }
    end.compact

    # Sort by ID for consistent output
    unique_citations.sort_by!(&:id)

    # Create output structure - use to_h from lutaml-model
    output = {
      "citations" => unique_citations.map(&:to_h)
    }

    File.write(output_file, YAML.dump(output))
    puts "✅ Done! Wrote #{unique_citations.size} unique citations"
  end

  def output_csv(output_file)
    puts "\n💾 Writing citations to #{output_file}..."

    # Get unique citations (one per title)
    unique_citations = @title_groups.values.map do |group|
      group.find { |c| c.id }
    end.compact

    # Sort by ID for consistent output
    unique_citations.sort_by!(&:id)

    # Get all unique item classes, sorted
    sorted_classes = @all_item_classes.to_a.sort

    CSV.open(output_file, "w") do |csv|
      # Write header with dynamic columns for each item class
      header = [
        "id",
        "title",
        "author",
        "publisher",
        "edition",
        "editionDate",
        "revisionDate",
        "seriesName",
        "seriesIssueID",
        "seriesPage",
        "isbn",
        "issn",
        "otherDetails",
        "uuid",
        "variants"
      ]

      # Add a column for each item class
      sorted_classes.each do |class_name|
        header << "referenced_by_#{class_name}"
      end

      # Add formula references column
      header << "referenced_by_formula_item"

      # Add referenced_as_uuid as last column
      header << "referenced_as_uuid"

      csv << header

      # Write data rows
      unique_citations.each_with_index do |citation, idx|
        title_key = normalize_title(citation.title)
        references = @citation_references[title_key] || []
        formula_refs = @formula_references[title_key] || []
        uuids = @citation_uuids[title_key] || []

        # Group references by class
        grouped_refs = references.group_by { |ref| ref[:class] }

        row = [
          idx + 1,
          citation.title,
          citation.author,
          citation.publisher,
          citation.edition,
          citation.edition_date,
          citation.revision_date,
          citation.series_name,
          citation.series_issue_id,
          citation.series_page,
          citation.isbn,
          citation.issn,
          citation.other_details,
          citation.uuid,
          citation.variants ? citation.variants.join(", ") : ""
        ]

        # Add referenced_by columns for each class
        sorted_classes.each do |class_name|
          if grouped_refs[class_name]
            identifiers = grouped_refs[class_name].map { |r| r[:identifier] }.compact.uniq.sort
            row << identifiers.join(", ")
          else
            row << ""
          end
        end

        # Add formula references column
        if formula_refs.any?
          formula_str = formula_refs.map do |ref|
            "#{ref[:class]}: #{ref[:identifier]}"
          end.join("; ")
          row << formula_str
        else
          row << ""
        end

        # Add all UUIDs as last column
        row << uuids.uniq.sort.join(", ")

        csv << row
      end
    end

    puts "✅ Done! Wrote #{unique_citations.size} unique citations"
  end

  def print_statistics
    puts ""
    puts "=" * 60
    puts "📊 EXTRACTION STATISTICS"
    puts "=" * 60
    puts "Files processed:           #{@stats[:files_processed]}"
    puts "Total citations found:     #{@stats[:citations_found]}"
    puts "Formula citations found:   #{@stats[:formula_citations_found]}"
    puts "Unique titles:             #{@stats[:unique_titles]}"
    puts "Citations with variants:   #{@stats[:citations_with_variants]}"
    puts "Item classes found:        #{@all_item_classes.size}"
    puts "=" * 60
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  registry_path = ARGV[0] || "gr-registry"
  output_file = ARGV[1] || "citations.yaml"
  csv_file = ARGV[2] || "citations.csv"

  unless Dir.exist?(registry_path)
    puts "❌ Error: Registry path '#{registry_path}' does not exist"
    puts ""
    puts "Usage: #{$PROGRAM_NAME} [registry_path] [output_file] [csv_file]"
    puts "  registry_path: Path to gr-registry directory (default: gr-registry)"
    puts "  output_file:   Output YAML file (default: citations.yaml)"
    puts "  csv_file:      Output CSV file (default: citations.csv)"
    exit 1
  end

  puts ""
  puts "╔════════════════════════════════════════════════════════════╗"
  puts "║          Citation Extractor for Geodetic Registry          ║"
  puts "╚════════════════════════════════════════════════════════════╝"
  puts ""

  extractor = CitationExtractor.new(registry_path)
  extractor.extract_all
  extractor.output_yaml(output_file)
  extractor.output_csv(csv_file)

  puts ""
  puts "🎉 Citation extraction complete!"
  puts ""
end