# Citation Register Implementation Plan

## Status: Phase 1 Complete - Extraction ✅

## Overview

This plan outlines the implementation of a centralized citation register for the ISO/TC 211 Geodetic Registry. The goal is to eliminate duplicate citation data across register items by creating a separate citation register item class that can be referenced.

## Architecture

### Current State ✅

Citations are embedded inline in register items in three places:
- `data.informationSources[]` - Array of citation objects
- `data.parameters[].fileCitation` - Citation object
- `data.formulaCitation` - Citation object (in coordinate-op-method)

### Target State

Citations will become a first-class register item:
- New item class: `citation`
- Sequential numeric identifiers (starting from max + 1)
- Register items reference citations by identifier instead of embedding full citation data

### Data Flow

```
┌─────────────────────────────────────────────┐
│  Phase 1: Extraction (COMPLETED)            │
└─────────────────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │  citations.yaml        │
         │  citations.csv         │
         │  - 256 unique citations│
         │  - Reference tracking  │
         └────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│  Phase 2: Citation Register Creation        │
│  - Assign sequential identifiers            │
│  - Create citation/*.yaml files             │
│  - Generate UUID for each citation          │
└─────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│  Phase 3: Schema Updates                    │
│  - Update all schemas with citation refs    │
│  - Replace inline citation type             │
│  - Add citation array type                  │
└─────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│  Phase 4: Register Item Updates             │
│  - Replace informationSources with IDs      │
│  - Replace fileCitation with ID             │
│  - Replace formulaCitation with ID/array    │
└─────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Citation Extraction ✅ COMPLETED

**Status:** Complete

**Outputs:**
- [`lib/citation.rb`](../lib/citation.rb) - Citation model class
- [`schemas/citation.yaml`](../schemas/citation.yaml) - Citation schema
- [`scripts/extract_citations.rb`](../scripts/extract_citations.rb) - Extraction script
- `citations.yaml` - 256 unique citations in YAML format
- `citations.csv` - Citations with reference tracking (36 columns)
- [`README.adoc`](../README.adoc) - Documentation

**Statistics:**
- 1,301 files processed (excluded 3,598 proposals)
- 256 unique citations extracted
- 26 citations with variants
- 32 formula citations found
- 17 citations with formula references
- 19 item classes identified

### Phase 2: Citation Register Creation

**Status:** Not Started

**Objectives:**
1. Determine latest identifier across all register items
2. Assign sequential identifiers to citations (start from max + 1)
3. Generate UUIDs for citation register items
4. Create citation/*.yaml files in gr-registry/

**Tasks:**

#### 2.1: Find Maximum Identifier

```ruby
# Script: scripts/find_max_identifier.rb
# Purpose: Scan all gr-registry/*.yaml files to find max identifier
# Output: Print max identifier number
```

**Expected output:** Max identifier number (e.g., 1500)

#### 2.2: Create Citation Register Items

```ruby
# Script: scripts/create_citation_items.rb
# Input: citations.csv
# Process:
#   - Read CSV
#   - For each citation:
#     - Assign identifier (sequential from max + 1)
#     - Generate UUID
#     - Create YAML file in gr-registry/citation/{uuid}.yaml
# Output: citation register items
```

**File structure:**
```
gr-registry/
└── citation/
    ├── {uuid-1}.yaml
    ├── {uuid-2}.yaml
    └── ...
```

**Citation item format:**
```yaml
id: {uuid}
data:
  identifier: {sequential-number}
  title: "..."
  author: "..."
  publisher: "..."
  # ... all other fields
dateAccepted: {date}
status: valid
```

### Phase 3: Schema Updates

**Status:** Not Started

**Objectives:**
Update all schemas to support citation references instead of inline citations.

**Files to Update:**

#### 3.1: Update coordinate-ops schemas

**Files:**
- `schemas/coordinate-ops--conversion.yaml`
- `schemas/coordinate-ops--transformation.yaml`

**Changes:**
```yaml
# OLD: informationSources as array of objects
informationSources:
  type: array
  items:
    type: object
    properties:
      author: ...
      title: ...
      # ... many fields

# NEW: informationSources as array of citation identifiers
informationSources:
  type: array
  items:
    type: integer
    description: Citation identifier reference
```

**Changes for fileCitation:**
```yaml
# OLD: fileCitation as object
fileCitation:
  type: ['null', object]
  properties:
    author: ...
    title: ...

# NEW: fileCitation as citation identifier
fileCitation:
  type: ['null', integer]
  description: Citation identifier reference
```

#### 3.2: Update coordinate-op-method schema

**File:** `schemas/coordinate-op-method.yaml`

**Changes:**
```yaml
# OLD: formulaCitation as object
formulaCitation:
  type: ['null', object]
  properties:
    author: ...
    title: ...

# NEW: formulaCitation as array of citation identifiers
formulaCitation:
  type: ['null', array]
  items:
    type: integer
  description: Array of citation identifier references
```

#### 3.3: Update all other schemas

**Files with informationSources:**
- `schemas/crs--geodetic.yaml`
- `schemas/crs--vertical.yaml`
- `schemas/datums--geodetic.yaml`
- `schemas/datums--vertical.yaml`
- `schemas/coordinate-sys-axis.yaml`
- ... (any schema with informationSources)

**Change pattern:** Same as 3.1

### Phase 4: Register Item Updates

**Status:** Not Started

**Objectives:**
Update all register items to reference citations by identifier instead of embedding full citation data.

#### 4.1: Create Update Script

```ruby
# Script: scripts/update_items_with_citations.rb
# Input: citations.csv (with assigned identifiers)
# Process:
#   - Load citation mappings (UUID -> identifier)
#   - For each register item YAML:
#     - Find informationSources citations by UUID match
#     - Replace with citation identifiers
#     - Find fileCitation by UUID match
#     - Replace with citation identifier
#     - Find formulaCitation by UUID match
#     - Replace with citation identifier(s)
#     - Write updated YAML
# Output: Updated register items
```

**Implementation approach:**

1. **Build citation lookup table:**
   ```ruby
   citation_lookup = {}  # uuid => identifier
   CSV.foreach('citations.csv') do |row|
     # Parse referenced_as_uuid column
     uuids = row[35].split(', ')
     identifier = row[0].to_i  # Sequential ID from CSV
     uuids.each { |uuid| citation_lookup[uuid] = identifier }
   end
   ```

2. **Process each register item:**
   ```ruby
   Dir.glob('gr-registry/**/*.yaml').each do |file|
     next if file.include?('/proposals/')
     
     data = YAML.unsafe_load(File.read(file))
     modified = false
     
     # Update informationSources
     if data.dig('data', 'informationSources')
       new_sources = data['data']['informationSources'].map do |source|
         citation_lookup[source['uuid']]
       end.compact
       data['data']['informationSources'] = new_sources
       modified = true
     end
     
     # Update fileCitation in parameters
     if data.dig('data', 'parameters')
       data['data']['parameters'].each do |param|
         if param['fileCitation'].is_a?(Hash)
           uuid = param['fileCitation']['uuid']
           param['fileCitation'] = citation_lookup[uuid]
           modified = true
         end
       end
     end
     
     # Update formulaCitation
     if data.dig('data', 'formulaCitation').is_a?(Hash)
       uuid = data['data']['formulaCitation']['uuid']
       data['data']['formulaCitation'] = [citation_lookup[uuid]].compact
       modified = true
     end
     
     File.write(file, YAML.dump(data)) if modified
   end
   ```

#### 4.2: Validation Script

```ruby
# Script: scripts/validate_citation_refs.rb
# Purpose: Validate all citation references
# Checks:
#   - All citation identifiers exist in citation register
#   - No inline citation objects remain
#   - All references are integers
# Output: Validation report
```

### Phase 5: Documentation Updates

**Status:** Not Started

**Tasks:**

1. **Update README.adoc** - Add section on citation register usage
2. **Create docs/citations-usage.adoc** - Detailed usage guide
3. **Move temporary docs** - Move `README_CITATIONS.md` to `old-docs/`

## Implementation Order

### Sprint 1: Citation Register Creation (1 day)

1. ✅ Phase 1 complete
2. Create `scripts/find_max_identifier.rb`
3. Create `scripts/create_citation_items.rb`
4. Run citation creation
5. Verify citation/*.yaml files

### Sprint 2: Schema Updates (1 day)

1. Update coordinate-ops schemas
2. Update coordinate-op-method schema
3. Update CRS and datum schemas
4. Update other schemas with informationSources
5. Validate all schemas

### Sprint 3: Item Updates (2 days)

1. Create `scripts/update_items_with_citations.rb`
2. Create backup of gr-registry
3. Run update script
4. Create `scripts/validate_citation_refs.rb`
5. Run validation
6. Fix any issues

### Sprint 4: Documentation (1 day)

1. Update README.adoc
2. Create usage documentation
3. Archive temporary documentation
4. Add migration guide

## Risks and Mitigation

### Risk 1: UUID Mismatches

**Risk:** Citation UUID in source might not match extracted UUID

**Mitigation:**
- Use the `referenced_as_uuid` column from CSV for matching
- Log all mismatches for manual review
- Provide fallback matching by title if UUID doesn't match

### Risk 2: Schema Validation Failures

**Risk:** Updated schemas might break existing validation

**Mitigation:**
- Keep backup of original schemas
- Update validators to handle integer references
- Test with sample files before full update

### Risk 3: Data Loss

**Risk:** Incorrect updates could lose citation data

**Mitigation:**
- Create full backup before any updates
- Implement dry-run mode in update script
- Verify all updates with validation script

## Success Criteria

1. ✅ All citations extracted and deduplicated
2. ⬜ Citation register items created with sequential identifiers
3. ⬜ All schemas updated to support citation references
4. ⬜ All register items updated with citation references
5. ⬜ No inline citation objects remain in register items
6. ⬜ All citation references validate correctly
7. ⬜ Documentation complete and accurate

## Testing Strategy

### Unit Tests

- Citation model serialization/deserialization
- Identifier validation
- UUID matching logic

### Integration Tests

- Citation extraction from various file types
- Citation register creation
- Register item updates

### Validation Tests

- All citation references resolve correctly
- No orphaned citations
- No inline citations remain

## Rollback Plan

If issues occur during Phase 4 (item updates):

1. Restore from backup
2. Review error logs
3. Fix update script
4. Re-run with dry-run mode
5. Verify and retry

## Notes

- Proposals directory is excluded from all operations
- Formula citations support arrays (multiple citations per formula)
- Identifier validation ensures data quality
- CSV provides full traceability for review