# Yiana Project Philosophy & History

## Project Name

**Yiana** - "Yiana Is Another Notes App"

A recursive acronym that acknowledges the crowded notes app space while positioning Yiana as a focused, purposeful entry that does specific things exceptionally well rather than trying to be everything to everyone.

## Core Philosophy: The LEGO Approach

### Fundamental Principle
> "Use proven Apple frameworks like LEGO blocks - leverage what they do best, avoid reinventing wheels, maintain simplicity over feature bloat."

### What This Means in Practice

1. **Trust Apple's Building Blocks**
   - PDFKit for PDF rendering (not custom PDF engines)
   - VisionKit for scanning (not custom camera implementations)
   - CloudKit for sync (not custom sync protocols)
   - UIDocument/NSDocument for file management (not Core Data)

2. **Simplicity Over Features**
   - Read-only PDF viewing (avoiding PDFKit annotation memory issues)
   - Clean document format (simple JSON + PDF, not complex databases)
   - Native UI patterns (users already know how to use them)
   - Single-purpose tools that work reliably

3. **Defensive Architecture**
   - Know the limitations of frameworks and respect them
   - Design around known issues rather than fighting them
   - Choose reliability over cutting-edge features
   - Accept trade-offs explicitly

## Project History

### Genesis (July 2024)
The project began with a clear vision: create a focused iOS/iPadOS note-taking app that excels at document scanning and PDF management. The initial specification deliberately excluded many common features (handwriting, real-time collaboration, direct cloud integration) to maintain focus.

### Key Architectural Decisions

#### Decision 1: No PDF Annotations (Initially)
- **Why**: PDFKit has well-documented memory issues with annotations
- **Trade-off**: Less functionality for more reliability
- **Result**: Stable app that handles large PDFs without crashes

#### Decision 2: Custom Document Format (.yianazip)
- **Why**: Need to store metadata alongside PDFs
- **Format**: Simple container with JSON metadata + PDF data
- **Benefit**: Easy to debug, extend, and maintain

#### Decision 3: Platform-Specific Implementations
- **Why**: iOS and macOS have different document models
- **Approach**: UIDocument for iOS, NSDocument for macOS
- **Result**: Native feel on each platform, no abstraction overhead

#### Decision 4: Server-Side OCR (Future)
- **Why**: OCR is computationally expensive on mobile devices
- **Plan**: Mac mini server handles heavy processing
- **Benefit**: Better battery life, faster device performance

### Evolution Timeline

#### Phase 1: Foundation (July-August 2024)
- Project setup with multiplatform support
- Basic document model implementation
- PDF viewing with PDFKit

#### Phase 2: Document Management (September-October 2024)
- Folder hierarchy implementation
- Document creation and organization
- Search functionality

#### Phase 3: Import/Export (November-December 2024)
- Bulk PDF import capabilities
- Stress testing with hundreds of documents
- Mass import scripts for large libraries
- PDF export functionality

#### Phase 4: Current (January 2025)
- Refinements to import process
- Folder context preservation
- Export functionality completion
- Considering markup integration (current proposal)

## Design Constraints & Trade-offs

### What We Deliberately Don't Do

1. **PDF Annotation/Markup** (until now)
   - Eliminated PDFKit memory issues
   - Simplified codebase significantly
   - Now reconsidering with QLPreviewController approach

2. **Handwriting/Drawing**
   - Avoided PencilKit integration complexity
   - Focused on document management over creation

3. **Real-time Collaboration**
   - Kept sync model simple
   - Avoided conflict resolution complexity

4. **Direct Cloud Service Integration**
   - Dropbox/Google Drive handled by Mac mini
   - Simplified app permissions and security

### Technical Principles

1. **Memory First**
   - Always consider memory impact
   - Prefer lazy loading and pagination
   - Release resources aggressively

2. **Fail Gracefully**
   - Never lose user data
   - Provide clear error messages
   - Always have a fallback

3. **Platform Native**
   - Use platform-specific UI patterns
   - Respect platform conventions
   - Don't force iOS patterns on macOS or vice versa

## Current State (January 2025)

### What Works Well
- ✅ Reliable PDF viewing without memory issues
- ✅ Fast document scanning and import
- ✅ Stable iCloud sync
- ✅ Clean, maintainable codebase
- ✅ Handles hundreds of documents efficiently

### Known Limitations
- 📝 No PDF markup (proposal in progress)
- 📝 No OCR yet (waiting for server component)
- 📝 Basic search (full-text search pending OCR)
- 📝 No handwriting support (by design)

### Active Development
- Investigating Apple Markup integration via QLPreviewController
- Planning Mac mini server integration for OCR
- Considering batch operations improvements

## Development Methodology

### Test-Driven Development (TDD)
- Write tests first when possible
- Maintain high test coverage for critical paths
- Use tests as documentation of intended behavior

### Small, Focused Changes
- Each commit does one thing
- Easy to review and revert if needed
- Clear commit messages explaining "why"

### Regular Deployments
- TestFlight builds for iOS
- Direct distribution for macOS
- Gather user feedback early and often

## Future Vision

### Near Term (Q1 2025)
- Apple Markup integration (current proposal)
- Improved search with partial matching
- Performance optimizations for large libraries

### Medium Term (Q2-Q3 2025)
- Mac mini OCR server integration
- Full-text search capabilities
- Advanced organization features

### Long Term (Q4 2025+)
- Automated document classification
- Smart folders with rules
- Workflow automation

## Success Metrics

### Technical
- Zero data loss incidents
- < 0.1% crash rate
- < 2 second document open time
- Handle 1000+ documents smoothly

### User Experience
- Minimal learning curve
- Familiar Apple-standard UI
- Reliable sync across devices
- Fast, responsive interface

## Contributing Philosophy

### For Contributors
1. Understand the LEGO philosophy before proposing features
2. Consider memory and performance impact
3. Prefer Apple frameworks over third-party dependencies
4. Write tests for new functionality
5. Document architectural decisions

### Code Review Standards
- Does it follow platform conventions?
- Is it the simplest solution that works?
- Have edge cases been considered?
- Is it maintainable by others?
- Does it respect our constraints?

## Conclusion

Yiana succeeds not by doing everything, but by doing specific things exceptionally well. By embracing Apple's frameworks as building blocks and accepting their limitations, we've created a stable, maintainable, and user-friendly application.

The LEGO philosophy isn't about limitation—it's about focus. Every decision is made with the understanding that reliability and simplicity create better user experiences than feature lists.

As we consider new features like markup support, we continue to apply these same principles: leverage what Apple provides, respect the constraints, and maintain the simplicity that makes Yiana reliable.

---

*"The best code is no code. The second best is code that uses proven frameworks correctly. Everything else is technical debt."* - Yiana Development Principle