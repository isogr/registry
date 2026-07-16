#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'json-schema'
require 'paint'
require 'fileutils'
require 'date'
require 'optparse'
require 'json'

# Validate all register items against their schemas
class RegisterValidator
  REGISTRY_DIR = 'gr-registry'
  SCHEMA_DIR = 'schemas'

  def initialize(options = {})
    @errors = []
    @warnings = []
    @success_count = 0
    @total_count = 0
    @max_files_per_class = options[:count]
    @verbose = options[:verbose]
  end

  def run
    puts Paint["=" * 80, :cyan]
    puts Paint["Register Item Validation", :cyan, :bold]
    if @max_files_per_class
      puts Paint["(Validating first #{@max_files_per_class} files per class)", :cyan]
    end
    if @verbose
      puts Paint["(Verbose mode: showing all files)", :cyan]
    else
      puts Paint["(Showing only failing files)", :cyan]
    end
    puts Paint["=" * 80, :cyan]
    puts

    register_item_classes = find_register_item_classes

    if register_item_classes.empty?
      puts Paint["No register item class directories found in #{REGISTRY_DIR}/", :red]
      return
    end

    register_item_classes.each do |item_class|
      validate_item_class(item_class)
    end

    print_summary
  end

  private

  def find_register_item_classes
    Dir.glob(File.join(REGISTRY_DIR, '*'))
       .select { |d| File.directory?(d) }
       .map { |d| File.basename(d) }
       .reject { |d| d.start_with?('_') || d == 'proposals' }
       .sort
  end

  def validate_item_class(item_class)
    schema_file = File.join(SCHEMA_DIR, "#{item_class}.yaml")

    unless File.exist?(schema_file)
      @warnings << "No schema found for #{item_class} (expected: #{schema_file})"
      return
    end

    puts Paint["Validating #{item_class}...", :blue, :bold]

    begin
      schema = YAML.safe_load_file(schema_file, permitted_classes: [Date, Time])
      # Remove $schema field if present as it causes validation issues
      schema.delete('$schema') if schema.is_a?(Hash)
    rescue StandardError => e
      @errors << {
        item_class: item_class,
        file: schema_file,
        error: "Failed to load schema: #{e.message}"
      }
      return
    end

    item_files = Dir.glob(File.join(REGISTRY_DIR, item_class, '*.yaml')).sort

    if item_files.empty?
      puts Paint["  No YAML files found", :yellow]
      return
    end

    # Limit files if count option is set
    item_files = item_files.take(@max_files_per_class) if @max_files_per_class

    item_files.each do |item_file|
      validate_item_file(item_class, item_file, schema)
    end

    puts
  end

  def convert_dates_to_strings(obj)
    case obj
    when Hash
      obj.transform_values { |v| convert_dates_to_strings(v) }
    when Array
      obj.map { |v| convert_dates_to_strings(v) }
    when Date
      obj.iso8601
    when Time
      obj.iso8601
    else
      obj
    end
  end

  def validate_item_file(item_class, item_file, schema)
    @total_count += 1
    filename = File.basename(item_file)

    begin
      data = YAML.safe_load_file(item_file, permitted_classes: [Date, Time, Symbol])

      # Convert Date/Time objects to strings for JSON Schema validation
      data_for_validation = convert_dates_to_strings(data)

      # Validate against JSON Schema
      errors = JSON::Validator.fully_validate(schema, data_for_validation, strict: false)

      if errors.empty?
        @success_count += 1
        if @verbose
          print Paint["  ✓ #{filename}", :green]
          puts
        end
      else
        @errors << {
          item_class: item_class,
          file: item_file,
          errors: errors
        }
        print Paint["  ✗ #{filename}", :red, :bold]
        puts
        errors.each do |error|
          puts Paint["    - #{error}", :red]
        end
      end
    rescue Psych::SyntaxError => e
      @errors << {
        item_class: item_class,
        file: item_file,
        error: "YAML syntax error: #{e.message}"
      }
      print Paint["  ✗ #{filename}", :red, :bold]
      puts
      puts Paint["    - YAML syntax error: #{e.message}", :red]
    rescue StandardError => e
      @errors << {
        item_class: item_class,
        file: item_file,
        error: "Validation error: #{e.message}"
      }
      print Paint["  ✗ #{filename}", :red, :bold]
      puts
      puts Paint["    - #{e.message}", :red]
    end
  end

  def print_summary
    puts Paint["=" * 80, :cyan]
    puts Paint["Validation Summary", :cyan, :bold]
    puts Paint["=" * 80, :cyan]
    puts

    # Print warnings
    unless @warnings.empty?
      puts Paint["Warnings:", :yellow, :bold]
      @warnings.each do |warning|
        puts Paint["  ⚠ #{warning}", :yellow]
      end
      puts
    end

    # Print statistics
    error_count = @errors.count
    puts Paint["Total files validated: #{@total_count}", :white, :bold]
    puts Paint["Successful validations: #{@success_count}", :green, :bold]

    if error_count > 0
      puts Paint["Failed validations: #{error_count}", :red, :bold]
      puts
      puts Paint["Files with violations:", :red, :bold]

      @errors.each do |error_info|
        file_relative = error_info[:file].sub("#{REGISTRY_DIR}/", '')
        puts Paint["  #{file_relative}", :red]

        if error_info[:errors]
          error_info[:errors].each do |err|
            puts Paint["    - #{err}", :red]
          end
        elsif error_info[:error]
          puts Paint["    - #{error_info[:error]}", :red]
        end
        puts
      end
    else
      puts Paint["Failed validations: 0", :green, :bold]
      puts
      puts Paint["✓ All files validated successfully!", :green, :bold]
    end

    puts Paint["=" * 80, :cyan]

    # Exit with appropriate code
    exit(error_count > 0 ? 1 : 0)
  end
end

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: validate_register.rb [options]"

  opts.on("--count N", Integer, "Validate only the first N files per class") do |n|
    options[:count] = n
  end

  opts.on("-v", "--verbose", "Show all files validated (default: show only failures)") do
    options[:verbose] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Run the validator
validator = RegisterValidator.new(options)
validator.run