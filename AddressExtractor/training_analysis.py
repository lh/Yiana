#!/usr/bin/env python3
"""
Training Data Analysis - Compare automated vs user-corrected addresses
Generates insights for improving extraction algorithms
"""

import sqlite3
from collections import defaultdict
from datetime import datetime
from pathlib import Path


class TrainingAnalyzer:
    def __init__(self, db_path: str):
        self.db_path = db_path

    def analyze_corrections(self):
        """Analyze patterns in user corrections"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("""
                SELECT
                    ea.document_id,
                    ea.extraction_method,
                    ea.extraction_confidence,
                    ea.full_name as original_name,
                    ea.postcode as original_postcode,
                    ao.full_name as corrected_name,
                    ao.postcode as corrected_postcode,
                    ao.override_reason,
                    ea.raw_text
                FROM address_overrides ao
                JOIN extracted_addresses ea ON ao.original_extraction_id = ea.id
                WHERE ao.is_training_candidate = 1
            """)

            corrections = cursor.fetchall()

        # Analyze patterns
        patterns = {
            'name_corrections': defaultdict(int),
            'postcode_corrections': defaultdict(int),
            'missing_by_method': defaultdict(int),
            'false_positives': defaultdict(int),
        }

        for row in corrections:
            doc_id, method, confidence, orig_name, orig_post, corr_name, corr_post, reason, text = row

            # Name correction patterns
            if orig_name != corr_name:
                if orig_name and corr_name:
                    patterns['name_corrections'][f"{orig_name} → {corr_name}"] += 1
                elif corr_name and not orig_name:
                    patterns['missing_by_method'][method] += 1

            # False positives
            if reason == 'removed':
                patterns['false_positives'][method] += 1

        return patterns

    def suggest_improvements(self):
        """Generate actionable improvement suggestions"""
        patterns = self.analyze_corrections()
        suggestions = []

        # Check for common false positives
        if patterns['false_positives']:
            suggestions.append({
                'priority': 'HIGH',
                'type': 'exclusion_rule',
                'description': 'Add exclusion patterns for common false positives',
                'examples': list(patterns['false_positives'].keys())
            })

        # Check for systematic name errors
        if patterns['name_corrections']:
            top_errors = sorted(
                patterns['name_corrections'].items(),
                key=lambda x: x[1],
                reverse=True
            )[:5]
            suggestions.append({
                'priority': 'MEDIUM',
                'type': 'regex_improvement',
                'description': 'Common name parsing errors',
                'examples': [f"{k} (x{v})" for k, v in top_errors]
            })

        return suggestions

    def generate_training_report(self, output_path: str):
        """Generate a markdown report for review"""
        patterns = self.analyze_corrections()
        suggestions = self.suggest_improvements()

        report = f"""# Address Extraction Training Report

Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}

## Summary

- Total corrections analyzed: {sum(sum(d.values()) for d in patterns.values())}
- Suggested improvements: {len(suggestions)}

## Correction Patterns

### Name Corrections
{self._format_dict(patterns['name_corrections'])}

### False Positives by Method
{self._format_dict(patterns['false_positives'])}

### Missing Extractions by Method
{self._format_dict(patterns['missing_by_method'])}

## Improvement Suggestions

"""
        for i, suggestion in enumerate(suggestions, 1):
            report += f"""
### {i}. {suggestion['description']} [{suggestion['priority']}]

**Type**: {suggestion['type']}

**Examples**:
"""
            for example in suggestion['examples']:
                report += f"- {example}\n"

        with open(output_path, 'w') as f:
            f.write(report)

        return output_path

    def _format_dict(self, d):
        if not d:
            return "None\n"
        return "\n".join(f"- {k}: {v}" for k, v in sorted(d.items(), key=lambda x: x[1], reverse=True))


if __name__ == "__main__":
    analyzer = TrainingAnalyzer("addresses.db")
    report_path = analyzer.generate_training_report("training_report.md")
    print(f"Training report generated: {report_path}")

    suggestions = analyzer.suggest_improvements()
    print(f"\n{len(suggestions)} improvement suggestions:")
    for s in suggestions:
        print(f"  [{s['priority']}] {s['description']}")
