# Citation Register Implementation Scripts

This directory contains scripts for implementing the centralized citation register for the ISO/TC 211 Geodetic Registry.

## Overview

The citation register implementation transforms inline citation objects scattered across register items into a centralized register with identifier-based references. This improves data consistency, reduces duplication, and simplifies citation management.

## Architecture

```
Inline Citations → Extract → Deduplicate → Create Items → Update References → Validate
     (1301 files)      ↓          ↓              ↓              ↓              ↓
                    citations   256 unique   citation/     Replace with    Check all
                      .yaml       titles      *.yaml        identifiers      refs valid
                    citations
                      .csv
```

## Scripts

### 1. extract_citations.rb

Extracts all citations from the registry and consolidates them.

**Purpose:** Phase 1 - Citation extraction and deduplication

**Usage:**
```bash
ruby scripts/extract_citations.rb [registry_path] [output_yaml] [output_csv]
```

**Parameters:**
- `registry_path`: Path to gr-registry directory (default: `gr-registry`)
- `output_yaml`: Output YAML file (default: `citations.yaml`)
- `output_csv`: Output CSV file (default: `citations.csv`)

**Example:**
```bash
ruby scripts/extract_citations.rb gr-registry citations.yaml citations.csv
```

**Output:**
- `citations.yaml` - All unique citations in YAML format
- `citations.csv` - Citations with complete reference tracking (36 columns)

**Documentation:** See [docs/extract-citations-documentation.adoc](../docs/extract-citations-documentation.adoc)

### 2. find_max_identifier.rb

Finds the maximum identifier value in the registry.

**Purpose:** Determine the starting identifier for new citation items

**Usage:**
```bash
ruby scripts/find_max_identifier.rb [registry_path]
```

**Parameters:**
- `registry_path`: Path to gr-registry directory (default: `gr-registry`)

**Example:**
```bash
ruby scripts/find_max_identifier.rb gr-registry
```

**Output:**
- Prints maximum identifier found
- Exit code is the max identifier value (for scripting)

### 3. create_citation_items.rb

Creates citation register items with sequential identifiers.

**Purpose:** Phase 2 - Citation register creation

**Usage:**
```bash
ruby scripts/create_citation_items.rb [csv_file] [registry_path] [start_identifier]
```

**Parameters:**
- `csv_file`: Path to citations CSV (default: `citations.csv`)
- `registry_path`: Path to gr-registry directory (default: `gr-registry`)
- `start_identifier`: Starting identifier (if not provided, finds max + 1)

**Example:**
```bash
ruby scripts/create_citation_items.rb citations.csv gr-registry 10000
```

**Output:**
- Creates `gr-registry/citation/*.yaml` files
- Updates CSV with `assigned_identifier` and `citation_item_uuid` columns

**Notes:**
- Automatically finds max identifier if not specified
- Creates citation directory if it doesn't exist
- Preserves original UUID for traceability

### 4. update_items_with_citations.rb

Updates register items to use citation identifiers instead of inline citations.

**Purpose:** Phase 3 - Replace inline citations with references

**Usage:**
```bash
ruby scripts/update_items_with_citations.rb [csv_file] [registry_path] [backup_dir]
```

**Parameters:**
- `csv_file`: Path to citations CSV (default: `citations.csv`)
- `registry_path`: Path to gr-registry directory (default: `gr-registry`)
- `backup_dir`: Optional backup directory (highly recommended)

**Example:**
```bash
ruby scripts/update_items_with_citations.rb citations.csv gr-registry backup
```

**Updates:**
- `data.informationSources[]` - Hash objects → integers
- `data.parameters[].fileCitation` - Hash object → integer
- `data.formulaCitation` - Hash object → array of integers

**Safety Features:**
- Creates backup if backup_dir specified
- Asks for confirmation if no backup
- Maps citations by UUID (most reliable) or title (fallback)
- Reports errors for unmapped citations

### 5. validate_citation_refs.rb

Validates all citation references in the registry.

**Purpose:** Phase 4 - Verify all references are valid

**Usage:**
```bash
ruby scripts/validate_citation_refs.rb [csv_file] [registry_path] [report_file]
```

**Parameters:**
- `csv_file`: Path to citations CSV (default: `citations.csv`)
- `registry_path`: Path to gr-registry directory (default: `gr-registry`)
- `report_file`: Optional detailed report file

**Example:**
```bash
ruby scripts/validate_citation_refs.rb citations.csv gr-registry validation_report.txt
```

**Validation Checks:**
- All citation references point to valid identifiers
- No inline citation objects remain
- No orphaned references
- Proper array format for formulaCitation

**Exit Codes:**
- 0: Validation passed
- 1: Validation failed

### 6. run_citation_pipeline.rb

Orchestrates the complete citation implementation pipeline.

**Purpose:** Run all phases in sequence with logging and error handling

**Usage:**
```bash
ruby scripts/run_citation_pipeline.rb [registry_path] [output_dir]
```

**Parameters:**
- `registry_path`: Path to gr-registry directory (default: `gr-registry`)
- `output_dir`: Output directory (default: `citation-output`)

**Example:**
```bash
ruby scripts/run_citation_pipeline.rb gr-registry citation-output
```

**Pipeline Phases:**
1. Extract citations → `citations.yaml`, `citations.csv`
2. Create citation items → `gr-registry/citation/*.yaml`
3. Update register items → Replace inline citations
4. Validate references → `validation_report.txt`

**Features:**
- Automatic backup creation
- Comprehensive logging
- Error handling and recovery
- Validation at the end

## Dependencies

All scripts require:
- Ruby 2.7 or higher
- lutaml-model gem

Install dependencies:
```bash
bundle install
```

## Workflow

### Complete Implementation

To run the complete citation implementation pipeline:

```bash
# Option 1: Use the pipeline orchestrator (recommended)
ruby scripts/run_citation_pipeline.rb

# Option 2: Run each phase manually
ruby scripts/extract_citations.rb
ruby scripts/create_citation_items.rb
ruby scripts/update_items_with_citations.rb backup
ruby scripts/validate_citation_refs.rb
```

### Individual Phases

#### Phase 1: Extract Citations

```bash
ruby scripts/extract_citations.rb gr-registry citations.yaml citations.csv
```

Review the output CSV to verify extraction quality.

#### Phase 2: Create Citation Register

```bash
# Find max identifier
ruby scripts/find_max_identifier.rb gr-registry

# Create citation items (auto-detects max identifier)
ruby scripts/create_citation_items.rb citations.csv gr-registry
```

Verify citation items were created in `gr-registry/citation/`.

#### Phase 3: Update Register Items

**IMPORTANT: Create a backup first!**

```bash
# Create backup manually
cp -r gr-registry gr-registry.backup

# Update items
ruby scripts/update_items_with_citations.rb citations.csv gr-registry
```

Review the update statistics for any errors.

#### Phase 4: Validate

```bash
ruby scripts/validate_citation_refs.rb citations.csv gr-registry validation_report.txt
```

Check the validation report for any issues.

## Output Files

### citations.yaml

YAML format with unique citations:

```yaml
citations:
  - id: citation-epsg_guidance_note_7_2
    title: "EPSG Guidance Note 7-2"
    author: "IOGP"
    publisher: "IOGP"
    editionDate: "2019-03"
```

### citations.csv

CSV format with 36+ columns:
- Columns 1-15: Basic citation fields
- Columns 16-34: `referenced_by_{class}` for each item class
- Column 35: `referenced_by_formula_item`
- Column 36: `referenced_as_uuid`
- Column 37: `assigned_identifier` (added by create_citation_items.rb)
- Column 38: `citation_item_uuid` (added by create_citation_items.rb)

### Citation Items

Each citation becomes a register item:

```yaml
id: 550d5e1e-a5f6-4d19-9d65-86e6b5c6e5fb
dateAccepted: 2024-01-15
status: valid
data:
  identifier: 10001
  name: "EPSG Guidance Note 7-2"
  title: "EPSG Guidance Note 7-2"
  author: "IOGP"
  publisher: "IOGP"
  editionDate: "2019-03"
  originalUuid: "abc-123-def-456"
```

### validation_report.txt

Detailed validation report with:
- Statistics
- List of errors (if any)
- List of warnings (if any)

## Error Handling

### Common Issues

#### Invalid Identifiers

**Error:** `Invalid identifier -1 in file xyz.yaml`

**Solution:** Fix the identifier in the source file before running extraction.

#### No Citation Mapping Found

**Error:** `No citation mapping found for: Some Title`

**Solution:** Check if the citation's UUID or title changed between extraction and update.

#### Validation Failures

**Error:** Inline citations still present after update

**Solution:** Re-run update script or manually fix remaining inline citations.

### Recovery

If something goes wrong during update:

```bash
# Restore from backup
rm -rf gr-registry
cp -r gr-registry.backup gr-registry

# Or use the pipeline's automatic backup
cp -r citation-output/backup_YYYYMMDD_HHMMSS/gr-registry .
```

## Testing

To test the scripts without modifying the registry:

```bash
# Test extraction only
ruby scripts/extract_citations.rb gr-registry test-output/citations.yaml test-output/citations.csv

# Test validation without updating
ruby scripts/validate_citation_refs.rb citations.csv gr-registry test-report.txt
```

## Performance

Typical performance on the ISO/TC 211 registry:

| Script | Files | Time | Memory |
|--------|-------|------|--------|
| extract_citations.rb | 1,301 | ~15s | ~150MB |
| find_max_identifier.rb | 1,301 | ~10s | ~100MB |
| create_citation_items.rb | 256 | ~2s | ~50MB |
| update_items_with_citations.rb | 1,301 | ~20s | ~150MB |
| validate_citation_refs.rb | 1,301 | ~15s | ~100MB |

Total pipeline: ~1-2 minutes

## Troubleshooting

### Script Won't Run

Check Ruby version:
```bash
ruby --version  # Should be 2.7 or higher
```

Install dependencies:
```bash
bundle install
```

### Out of Memory

For very large registries, increase Ruby heap size:
```bash
RUBY_GC_HEAP_INIT_SLOTS=2000000 ruby scripts/extract_citations.rb
```

### CSV Column Mismatch

Ensure proper column order by regenerating CSV:
```bash
rm citations.csv
ruby scripts/extract_citations.rb
```

## Contributing

When modifying these scripts:

1. Follow Ruby style guide in `.kilocode/rules/ruby-code.md`
2. Update this README with any changes
3. Test on a small subset before full registry
4. Add error handling for new failure modes
5. Update documentation in `docs/`

## References

- [Implementation Plan](../docs/citations-implementation-plan.md)
- [Continuation Prompt](../docs/citations-continuation-prompt.md)
- [Extract Citations Documentation](../docs/extract-citations-documentation.adoc)
- [Citation Schema](../schemas/citation.yaml)
- [Citation Model](citation.rb)

## Support

For issues or questions:
1. Check this README first
2. Review error messages carefully
3. Check validation report for details
4. Consult implementation plan documentation