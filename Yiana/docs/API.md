# Yiana API Documentation

## DocumentMetadata API

### Initialization
```swift
init(id: UUID = UUID(),
     title: String,
     created: Date = Date(),
     modified: Date = Date(),
     pageCount: Int = 0,
     tags: [String] = [],
     ocrCompleted: Bool = false,
     fullText: String? = nil)
```

### Properties
All properties follow Swift naming conventions and are self-documenting.

### Codable Conformance
DocumentMetadata conforms to Codable for JSON serialization:
```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let data = try encoder.encode(metadata)

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let metadata = try decoder.decode(DocumentMetadata.self, from: data)
```

## NoteDocument API (iOS)

### Initialization
```swift
override init(fileURL url: URL)
```
Creates a new document at the specified URL with default metadata.

### Properties
```swift
var pdfData: Data?              // The PDF content
var metadata: DocumentMetadata  // Document metadata
```

### Key Methods

#### Save Document
```swift
// Inherited from UIDocument
save(to: URL, for: UIDocument.SaveOperation, completionHandler: (Bool) -> Void)
```

#### Open Document
```swift
// Inherited from UIDocument
open(completionHandler: (Bool) -> Void)
```

#### Document Type
```swift
override var fileType: String? {
    return UTType.yianaDocument.identifier  // "com.vitygas.yiana.document"
}
```

### Internal Methods

#### Contents for Type
```swift
override func contents(forType typeName: String) throws -> Any
```
Serializes metadata and PDF data into the .yianazip format.

#### Load from Contents
```swift
override func load(fromContents contents: Any, ofType typeName: String?) throws
```
Deserializes .yianazip data into metadata and PDF data.

## Error Handling

### CocoaError Usage
The API uses standard CocoaError for file operations:
- `.fileReadCorruptFile` - Invalid file format
- `.fileReadNoSuchFile` - File doesn't exist
- `.fileWriteUnknown` - Write operation failed

### Example Error Handling
```swift
do {
    try document.load(fromContents: data, ofType: nil)
} catch CocoaError.fileReadCorruptFile {
    // Handle corrupt file
} catch {
    // Handle other errors
}
```

## Thread Safety

- DocumentMetadata is a value type (struct) - inherently thread-safe
- NoteDocument follows UIDocument threading rules:
  - UI operations on main thread
  - File operations on background queues
  - Completion handlers called on main thread

## Best Practices

1. **Always check fileURL before operations**
   ```swift
   guard let url = document.fileURL else { return }
   ```

2. **Handle completion handlers properly**
   ```swift
   document.save(to: url, for: .forCreating) { success in
       if success {
           // Update UI
       } else {
           // Show error
       }
   }
   ```

3. **Update modified date on changes**
   ```swift
   document.metadata.modified = Date()
   ```

4. **Use appropriate save operations**
   - `.forCreating` - New documents
   - `.forOverwriting` - Existing documents