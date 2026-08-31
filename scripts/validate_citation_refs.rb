#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "csv"
require "set"

# Validates citation references in register items
class CitationReferenceValidator
  attr_reader :validation_errors, :validation_warnings

  def initialize(csv_file, registry_path)
    @csv_file = csv_file
    @registry_path = registry_path
    @valid_identifiers = Set.new
    @validation_errors = []
    @validation_warnings = []
    @stats = {
      files_validated: 0,
      citation_refs_found: 0,
      inline_citations_found: 0,
      invalid_refs_found: 0,
      files_skipped: 0
    }
  end

  def validate_all
    puts "📖 Reading valid citation identifiers from #{@csv_file}..."
    
    unless File.exist?(@csv_file)
      raise "❌ Error: CSV file '#{@csv_file}' does not exist"
    end

    load_valid_identifiers

    puts "✅ Loaded #{@valid_identifiers.size} valid citation identifiers"
    puts ""

    puts "🔍 Scanning for YAML files in #{@registry_path}..."
    all_files = Dir.glob(File.join(@registry_path, "**", "*.yaml"))

    # Exclude proposals directory
    yaml_files = all_files.reject { |f| f.include?("/proposals/") }

    puts "📄 Found #{yaml_files.size} YAML files to validate"
    puts ""

    puts "✔️  Validating citation references..."
    yaml_files.each_with_index do |file, idx|
      process_file(file)
      print "\r⏳ Progress: #{idx + 1}/#{yaml_files.size} files" if (idx + 1) % 10 == 0
    end

    puts "\n"
    print_statistics
    print_validation_results
  end

  def load_valid_identifiers
    csv_data = CSV.read(@csv_file, headers: true)

    csv_data.each do |row|
      identifier = row["assigned_identifier"]&.to_i
      @valid_identifiers << identifier if identifier && identifier > 0
    end
  end

  def process_file(file)
    @stats[:files_validated] += 1

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
        @validation_warnings << {
          file: file,
          type: "parse_error",
          message: "Failed to load YAML: #{e.message}"
        }
        return
      end
    end

    return unless data.is_a?(Hash)
    
    # Validate informationSources
    if data.dig("data", "informationSources").is_a?(Array)
      sources = data["data"]["informationSources"]
      sources.each_with_index do |source, idx|
        validate_citation_reference(source, file, "informationSources[#{idx}]")
      end
    end

    # Validate fileCitation in parameters
    if data.dig("data", "parameters").is_a?(Array)
      params = data["data"]["parameters"]
      params.each_with_index do |param, idx|
        next unless param.is_a?(Hash) && param["fileCitation"]
        
        validate_citation_reference(
          param["fileCitation"],
          file,
          "parameters[#{idx}].fileCitation"
        )
      end
    end

    # Validate formulaCitation
    if data.dig("data", "formulaCitation")
      formula_citation = data["data"]["formulaCitation"]
      validate_citation_reference(formula_citation, file, "formulaCitation")
    end
  rescue StandardError => e
    @validation_warnings << {
      file: file,
      type: "validation_error",
      message: "Failed to validate: #{e.message}"
    }
    @stats[:files_skipped] += 1
  end

  def validate_citation_reference(reference, file, path)
    if reference.is_a?(Hash)
      # This is an inline citation object - should have been replaced
      @stats[:inline_citations_found] += 1
      @validation_errors << {
        file: file,
        path: path,
        type: "inline_citation",
        message: "Inline citation object found (should be integer reference)",
        data: reference
      }
    elsif reference.is_a?(Integer)
      # This is a citation reference - validate it
      @stats[:citation_refs_found] += 1
      
      unless @valid_identifiers.include?(reference)
        @stats[:invalid_refs_found] += 1
        @validation_errors << {
          file: file,
          path: path,
          type: "invalid_reference",
          message: "Reference to non-existent citation: #{reference}",
          data: reference
        }
      end
    elsif reference.is_a?(Array)
      # Array of citations (for formulaCitation)
      reference.each_with_index do |ref, idx|
        if ref.is_a?(Hash)
          @stats[:inline_citations_found] += 1
          @validation_errors << {
            file: file,
            path: "#{path}[#{idx}]",
            type: "inline_citation",
            message: "Inline citation object in array (should be integer)",
            data: ref
          }
        elsif ref.is_a?(Integer)
          @stats[:citation_refs_found] += 1
          
          unless @valid_identifiers.include?(ref)
            @stats[:invalid_refs_found] += 1
            @validation_errors << {
              file: file,
              path: "#{path}[#{idx}]",
              type: "invalid_reference",
              message: "Reference to non-existent citation: #{ref}",
              data: ref
            }
          end
        end
      end
    elsif !reference.nil?
      # Unexpected type
      @validation_warnings << {
        file: file,
        path: path,
        type: "unexpected_type",
        message: "Unexpected citation reference type: #{reference.class}",
        data: reference
      }
    end
  end

  def print_statistics
    puts ""
    puts "=" * 60
    puts "📊 VALIDATION STATISTICS"
    puts "=" * 60
    puts "Files validated:           #{@stats[:files_validated]}"
    puts "Files skipped:             #{@stats[:files_skipped]}"
    puts "Citation refs found:       #{@stats[:citation_refs_found]}"
    puts "Inline citations found:    #{@stats[:inline_citations_found]}"
    puts "Invalid refs found:        #{@stats[:invalid_refs_found]}"
    puts ""
    puts "Validation errors:         #{@validation_errors.size}"
    puts "Validation warnings:       #{@validation_warnings.size}"
    puts "=" * 60
  end

  def print_validation_results
    if @validation_errors.empty? && @validation_warnings.empty?
      puts ""
      puts "✅ VALIDATION PASSED!"
      puts "   All citation references are valid and no inline citations found."
      return
    end

    # Print errors
    if @validation_errors.any?
      puts ""
      puts "❌ VALIDATION ERRORS"
      puts "=" * 60

      # Group errors by type
      error_groups = @validation_errors.group_by { |e| e[:type] }

      error_groups.each do |error_type, errors|
        puts ""
        puts "#{error_type.upcase.gsub('_', ' ')} (#{errors.size} occurrences):"
        
        # Show first 10 examples
        errors.first(10).each do |error|
          puts "  File: #{error[:file]}"
          puts "  Path: #{error[:path]}"
          puts "  Message: #{error[:message]}"
          if error[:data]
            puts "  Data: #{error[:data].inspect}"
          end
          puts ""
        end

        if errors.size > 10
          puts "  ... and #{errors.size - 10} more #{error_type} errors"
          puts ""
        end
      end
    end

    # Print warnings
    if @validation_warnings.any?
      puts ""
      puts "⚠️  VALIDATION WARNINGS"
      puts "=" * 60

      # Group warnings by type
      warning_groups = @validation_warnings.group_by { |w| w[:type] }

      warning_groups.each do |warning_type, warnings|
        puts ""
        puts "#{warning_type.upcase.gsub('_', ' ')} (#{warnings.size} occurrences):"
        
        # Show first 5 examples
        warnings.first(5).each do |warning|
          puts "  File: #{warning[:file]}"
          puts "  Message: #{warning[:message]}"
        end

        if warnings.size > 5
          puts "  ... and #{warnings.size - 5} more #{warning_type} warnings"
        end
        puts ""
      end
    end

    puts "=" * 60
  end

  def generate_report(output_file)
    puts ""
    puts "📝 Generating detailed report to #{output_file}..."

    File.open(output_file, "w") do |f|
      f.puts "Citation Reference Validation Report"
      f.puts "=" * 60
      f.puts "Generated: #{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')}"
      f.puts ""
      f.puts "Registry Path: #{@registry_path}"
      f.puts "Citation CSV: #{@csv_file}"
      f.puts ""
      
      f.puts "STATISTICS"
      f.puts "-" * 60
      f.puts "Files validated:           #{@stats[:files_validated]}"
      f.puts "Files skipped:             #{@stats[:files_skipped]}"
      f.puts "Citation refs found:       #{@stats[:citation_refs_found]}"
      f.puts "Inline citations found:    #{@stats[:inline_citations_found]}"
      f.puts "Invalid refs found:        #{@stats[:invalid_refs_found]}"
      f.puts ""
      f.puts "Validation errors:         #{@validation_errors.size}"
      f.puts "Validation warnings:       #{@validation_warnings.size}"
      f.puts ""

      if @validation_errors.any?
        f.puts "ERRORS"
        f.puts "-" * 60
        @validation_errors.each_with_index do |error, idx|
          f.puts ""
          f.puts "Error ##{idx + 1}"
          f.puts "  File: #{error[:file]}"
          f.puts "  Path: #{error[:path]}"
          f.puts "  Type: #{error[:type]}"
          f.puts "  Message: #{error[:message]}"
          f.puts "  Data: #{error[:data].inspect}" if error[:data]
        end
        f.puts ""
      end

      if @validation_warnings.any?
        f.puts "WARNINGS"
        f.puts "-" * 60
        @validation_warnings.each_with_index do |warning, idx|
          f.puts ""
          f.puts "Warning ##{idx + 1}"
          f.puts "  File: #{warning[:file]}"
          f.puts "  Type: #{warning[:type]}"
          f.puts "  Message: #{warning[:message]}"
        end
        f.puts ""
      end
    end

    puts "✅ Report generated"
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  csv_file = ARGV[0] || "citations.csv"
  registry_path = ARGV[1] || "gr-registry"
  report_file = ARGV[2]

  unless File.exist?(csv_file)
    puts "❌ Error: CSV file '#{csv_file}' does not exist"
    puts ""
    puts "Usage: #{$PROGRAM_NAME} [csv_file] [registry_path] [report_file]"
    puts "  csv_file:      Path to citations CSV file (default: citations.csv)"
    puts "  registry_path: Path to gr-registry directory (default: gr-registry)"
    puts "  report_file:   Optional detailed report file"
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
  puts "║   Citation Reference Validator for Geodetic Registry       ║"
  puts "╚════════════════════════════════════════════════════════════╝"
  puts ""

  validator = CitationReferenceValidator.new(csv_file, registry_path)
  validator.validate_all

  # Generate detailed report if requested
  if report_file
    validator.generate_report(report_file)
  end

  puts ""
  
  # Exit with error code if validation failed
  if validator.validation_errors.any?
    puts "❌ Validation failed with #{validator.validation_errors.size} errors"
    exit 1
  else
    puts "✅ Validation completed successfully!"
    exit 0
  end
end