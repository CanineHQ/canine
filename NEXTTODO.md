# Add-On Create Path Refactoring

## Overview
Refactor add-on creation to use `repository_url` and `chart_url` consistently across all three creation paths.

## Path 1: Preselected Chart from charts.yml (PostgreSQL, Redis, etc.)

**User Action:** Clicks a predefined card (e.g., PostgreSQL)

**Flow:**
1. chart_type = "postgresql" (from card)
2. chart_url = "bitnami/postgresql" (from charts.yml)
3. Call `SetPackageDetails` → `FetchChartDetailsFromArtifactHub`
4. Store **unchanged** Artifact Hub response in `metadata['artifact_hub']`
5. Extract `repository_url` from response
6. Set top-level display fields from charts.yml:
   - `metadata['logo']` = from charts.yml
   - `metadata['display_name']` = from charts.yml
   - `metadata['description']` = from charts.yml (if present)
7. **Result:** repository_url, chart_url, version, metadata stored

## Path 2: Artifact Hub Search (helm_chart)

**User Action:** Searches Artifact Hub, selects a chart

**Flow:**
1. User searches via helm-search controller
2. Selects chart → sets chart_url (e.g., "grafana/grafana")
3. Call `SetPackageDetails` → `FetchChartDetailsFromArtifactHub`
4. Store **unchanged** Artifact Hub response in `metadata['artifact_hub']`
5. Extract `repository_url` from response
6. Set top-level display fields from Artifact Hub response:
   - `metadata['logo']` = from artifact_hub response
   - `metadata['display_name']` = from artifact_hub response
   - `metadata['description']` = from artifact_hub response
7. **Result:** repository_url, chart_url, version, metadata stored

## Path 3: Custom Repository URL

**User Action:** Enters custom repository URL

**Flow:**
1. User enters `repository_url` (e.g., "https://czhu12.github.io/openclaw-helm")
2. Fetch index.yaml via `FetchChartDetailsFromRepositoryUrl`
3. User selects chart name (e.g., "openclaw")
4. Derive `repo_name` from URL (e.g., "openclaw-helm")
5. Construct `chart_url` = "openclaw-helm/openclaw"
6. Store **unchanged** repository index in `metadata['repository_index']`
7. Set minimal top-level display fields:
   - `metadata['logo']` = null or default
   - `metadata['display_name']` = chart_name
8. **Result:** repository_url, chart_url, version, metadata stored

## Key Principle: Don't Modify Payloads

- Store API responses **unchanged** in `metadata['artifact_hub']` or `metadata['repository_index']`
- Extract display values to top-level `metadata` fields
- UI always reads from top-level fields (`metadata['logo']`, `metadata['display_name']`)
- Original payloads remain intact for debugging/reference

## Required Fields for All Paths

After creation, all add-ons should have:
- `repository_url` (NOT NULL) - The actual Helm repository URL
- `chart_url` - Format: "repo_name/chart_name"
- `version` - The chart version to install
- `metadata['logo']` - Display logo (curated for Path 1, from API for Path 2, null/default for Path 3)
- `metadata['display_name']` - Display name (matches Artifact Hub naming)
- `metadata['artifact_hub']` OR `metadata['repository_index']` - Unchanged source payload
- `chart_type` - TBD: Do we still need this or can we remove it?

## Metadata Structure

**Path 1 (Curated Charts):**
```json
{
  // Top-level display fields (FROM charts.yml)
  "logo": "/images/helm/postgresql.webp",
  "display_name": "PostgreSQL",
  "description": "Our curated PostgreSQL setup...",

  // Unchanged Artifact Hub payload
  "artifact_hub": {
    "logo": "https://artifacthub.io/image/...",
    "display_name": "postgresql",
    "repository": {
      "name": "bitnami",
      "url": "https://charts.bitnami.com/bitnami"
    },
    // ... full unchanged response
  }
}
```

**Path 2 (Artifact Hub Search):**
```json
{
  // Top-level display fields (FROM artifact_hub response)
  "logo": "https://artifacthub.io/image/...",
  "display_name": "Grafana",
  "description": "...",

  // Unchanged Artifact Hub payload
  "artifact_hub": {
    "logo": "https://artifacthub.io/image/...",
    "display_name": "Grafana",
    "repository": {
      "name": "grafana",
      "url": "https://grafana.github.io/helm-charts"
    },
    // ... full unchanged response
  }
}
```

**Path 3 (Custom Repo):**
```json
{
  // Top-level display fields (minimal)
  "logo": null,
  "display_name": "openclaw",

  // Unchanged repository index data
  "repository_index": {
    "chart_name": "openclaw",
    "available_versions": ["1.0.0", "0.9.0"],
    // ... from index.yaml
  }
}
```

## charts.yml Structure for Path 1

```yaml
helm:
  charts:
    - name: postgresql
      chart_url: bitnami/postgresql
      display_name: PostgreSQL
      logo: /images/helm/postgresql.webp
      description: "Our curated PostgreSQL setup..."
      # These populate top-level metadata fields
```

## Implementation Notes

1. Never modify API response payloads - store them unchanged
2. Always populate top-level display fields (`metadata['logo']`, `metadata['display_name']`)
3. UI reads from top-level fields only, never directly from payloads
4. Use "display_name" consistently (matches Artifact Hub naming convention)
5. `SetPackageDetails` needs to:
   - Store unchanged response in `metadata['artifact_hub']` or `metadata['repository_index']`
   - Extract/set top-level display fields based on path
6. For Path 1: charts.yml values override what would come from Artifact Hub
7. Repository name derivation from URL needs to be consistent
8. Rename existing `package_details` to `artifact_hub` in migration/backfill
