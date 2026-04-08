#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "time"

# Orchestrates the complete citation register implementation pipeline
class CitationPipeline
  def initialize(registry_path, output_dir = "citation-output")
    @registry_path = registry_path
    @output_dir = output_dir
    @timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    @backup_dir = File.join(@output_dir, "backup_#{@timestamp}")
    @log_file = File.join(@output_dir, "pipeline_#{@timestamp}.log")
    @errors = []
  end

  def run
    setup_output_directory
    
    log_header
    
    begin
      # Phase 1: Extract citations
      log_phase(1, "Citation Extraction")
      run_extraction
      
      # Phase 2: Create citation register items
      log_phase(2, "Citation Register Creation")
      run_citation_creation
      
      # Phase 3: Update register items with citations
      log_phase(3, "Register Item Updates")
      run_item_updates
      
      # Phase 4: Validate citation references
      log_phase(4, "Citation Reference Validation")
      run_validation
      
      log_completion
    rescue StandardError => e
      log_error("Pipeline failed: #{e.message}")
      log_error(e.backtrace.join("\n"))
      exit 1
    end
  end

  private

  def setup_output_directory
    FileUtils.mkdir_p(@output_dir)
    puts "📁 Output directory: #{@output_dir}"
    puts "📝 Log file: #{@log_file}"
    puts ""
  end

  def log_header
    message = <<~HEADER
      ╔════════════════════════════════════════════════════════════╗
      ║         Citation Register Implementation Pipeline          ║
      ╚════════════════════════════════════════════════════════════╝
      
      Started: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
      Registry Path: #{@registry_path}
      Output Directory: #{@output_dir}
      Backup Directory: #{@backup_dir}
      
    HEADER
    
    log(message)
  end

  def log_phase(number, name)
    message = <<~PHASE
      
      ═══════════════════════════════════════════════════════════════
      PHASE #{number}: #{name}
      ═══════════════════════════════════════════════════════════════
      
    PHASE
    
    log(message)
  end

  def run_extraction
    csv_file = File.join(@output_dir, "citations.csv")
    yaml_file = File.join(@output_dir, "citations.yaml")
    
    log("Extracting citations from registry...")
    log("Output: #{csv_file}, #{yaml_file}")
    
    require_relative "extract_citations"
    
    extractor = CitationExtractor.new(@registry_path)
    extractor.extract_all
    extractor.output_yaml(yaml_file)
    extractor.output_csv(csv_file)
    
    log("✅ Extraction complete: #{extractor.citations.size} unique citations found")
  rescue StandardError => e
    log_error("Extraction failed: #{e.message}")
    raise
  end

  def run_citation_creation
    csv_file = File.join(@output_dir, "citations.csv")
    
    log("Finding maximum identifier in registry...")
    
    require_relative "find_max_identifier"
    
    finder = MaxIdentifierFinder.new(@registry_path)
    finder.find_max
    max_id = finder.max_identifier
    start_id = max_id + 1
    
    log("Maximum identifier: #{max_id}")
    log("Starting citation identifiers from: #{start_id}")
    log("")
    log("Creating citation register items...")
    
    require_relative "create_citation_items"
    
    creator = CitationItemCreator.new(csv_file, @registry_path, start_id)
    creator.create_all
    
    log("✅ Citation creation complete: #{creator.citations_created} items created")
    log("   Identifiers: #{start_id} to #{start_id + creator.citations_created - 1}")
  rescue StandardError => e
    log_error("Citation creation failed: #{e.message}")
    raise
  end

  def run_item_updates
    csv_file = File.join(@output_dir, "citations.csv")
    
    log("Creating backup of registry...")
    log("Backup location: #{@backup_dir}")
    
    FileUtils.mkdir_p(@backup_dir)
    FileUtils.cp_r(@registry_path, @backup_dir)
    
    log("✅ Backup created")
    log("")
    log("Updating register items with citation references...")
    
    require_relative "update_items_with_citations"
    
    updater = CitationReferenceUpdater.new(csv_file, @registry_path, nil)
    updater.update_all
    
    log("✅ Update complete: #{updater.files_updated} files updated")
    log("   Citations replaced: #{updater.citations_replaced}")
  rescue StandardError => e
    log_error("Item update failed: #{e.message}")
    log_error("Registry backup is available at: #{@backup_dir}")
    raise
  end

  def run_validation
    csv_file = File.join(@output_dir, "citations.csv")
    report_file = File.join(@output_dir, "validation_report.txt")
    
    log("Validating citation references...")
    log("Report: #{report_file}")
    
    require_relative "validate_citation_refs"
    
    validator = CitationReferenceValidator.new(csv_file, @registry_path)
    validator.validate_all
    validator.generate_report(report_file)
    
    if validator.validation_errors.empty?
      log("✅ Validation passed: No errors found")
    else
      log_error("❌ Validation failed: #{validator.validation_errors.size} errors found")
      log_error("See detailed report: #{report_file}")
      @errors << "Validation failed with #{validator.validation_errors.size} errors"
    end
  rescue StandardError => e
    log_error("Validation failed: #{e.message}")
    raise
  end

  def log_completion
    status = @errors.empty? ? "SUCCESS" : "COMPLETED WITH ERRORS"
    
    message = <<~COMPLETION
      
      ═══════════════════════════════════════════════════════════════
      PIPELINE #{status}
      ═══════════════════════════════════════════════════════════════
      
      Completed: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
      
      Output Files:
        - #{File.join(@output_dir, 'citations.csv')}
        - #{File.join(@output_dir, 'citations.yaml')}
        - #{File.join(@output_dir, 'validation_report.txt')}
      
      Backup:
        - #{@backup_dir}
      
    COMPLETION
    
    if @errors.any?
      message += "Errors:\n"
      @errors.each do |error|
        message += "  - #{error}\n"
      end
      message += "\n"
    end
    
    message += "See detailed log: #{@log_file}\n"
    
    log(message)
    
    exit(@errors.empty? ? 0 : 1)
  end

  def log(message)
    puts message
    File.open(@log_file, "a") { |f| f.puts(message) }
  end

  def log_error(message)
    error_msg = "ERROR: #{message}"
    puts error_msg
    File.open(@log_file, "a") { |f| f.puts(error_msg) }
    @errors << message
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  registry_path = ARGV[0] || "gr-registry"
  output_dir = ARGV[1] || "citation-output"

  unless Dir.exist?(registry_path)
    puts "❌ Error: Registry path '#{registry_path}' does not exist"
    puts ""
    puts "Usage: #{$PROGRAM_NAME} [registry_path] [output_dir]"
    puts "  registry_path: Path to gr-registry directory (default: gr-registry)"
    puts "  output_dir:    Output directory for results (default: citation-output)"
    exit 1
  end

  pipeline = CitationPipeline.new(registry_path, output_dir)
  pipeline.run
end