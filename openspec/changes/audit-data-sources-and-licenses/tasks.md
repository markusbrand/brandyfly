## 1. Governance Schemas

- [ ] 1.1 Define the versioned provider-dataset record with evidence, decision, review, licence, privacy, and operational fields
- [ ] 1.2 Define package-manifest provenance and attribution fields required by the specification
- [ ] 1.3 Add schema fixtures for approved, rejected, blocked, expired, revoked, and personal-data candidates
- [ ] 1.4 Add validation tests that reject incomplete approval records and package manifests

## 2. Provider Research

- [ ] 2.1 Audit base-map extract candidates, including OSM and Geofabrik terms for derived offline distribution
- [ ] 2.2 Audit elevation, contours, and hillshade candidates for source attribution and derived-data rights
- [ ] 2.3 Audit airspace candidates, including OpenAIP and open flightmaps, for coverage, update, cache, and redistribution limits
- [ ] 2.4 Audit online and offline geocoding candidates for storage and attribution restrictions
- [ ] 2.5 Audit live-pilot candidates for interface permission, consent, retention, deletion, and onward-sharing constraints
- [ ] 2.6 Audit thermal-source or thermal-derivation candidates for input rights, attribution, privacy, and retention

## 3. Decisions and Safety Responses

- [ ] 3.1 Classify every candidate as approved, rejected, or blocked with authoritative evidence, date, reviewer, and revalidation date
- [ ] 3.2 Confirm every required category has an approved provider or explicitly gate its dependent roadmap work
- [ ] 3.3 Document responses for source outage, stale data, changed terms, review expiry, and permission revocation
- [ ] 3.4 Document how new publication stops without deleting a pilot's only installed offline data during flight
- [ ] 3.5 Review all repository additions for tokens, personal locations, restricted correspondence, and non-redistributable data

## 4. Enforcement and Verification

- [ ] 4.1 Add a repository validation command that detects invalid, incomplete, and expired provider records
- [ ] 4.2 Add package-manifest validation that blocks missing provenance or attribution
- [ ] 4.3 Integrate the targeted governance checks into the existing CI workflow
- [ ] 4.4 Publish the engineering audit with an explicit non-legal-advice boundary and verify OpenSpec strict validation passes
