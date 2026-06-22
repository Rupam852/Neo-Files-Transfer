# Download File Function

<cite>
**Referenced Files in This Document**
- [download-file/index.ts](file://supabase/functions/download-file/index.ts)
- [generate-share-link/index.ts](file://supabase/functions/generate-share-link/index.ts)
- [DownloadPage.jsx](file://web/src/pages/DownloadPage.jsx)
- [001_initial_schema.sql](file://supabase/migrations/001_initial_schema.sql)
- [config.toml](file://supabase/config.toml)
- [supabase.js](file://web/src/services/supabase.js)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
The download-file edge function is a serverless function that handles public file downloads in the Neo Files Transfer system. It validates share hashes, checks file permissions, verifies system availability, and securely redirects users to Google Drive for file downloads. This function serves as a bridge between the frontend interface and Google Drive's public file access capabilities.

## Project Structure
The download functionality spans three main areas of the system:

```mermaid
graph TB
subgraph "Web Interface"
WP[DownloadPage.jsx]
SP[Supabase Client]
end
subgraph "Edge Functions"
DF[download-file/index.ts]
GSL[generate-share-link/index.ts]
end
subgraph "Database Layer"
SF[shared_files table]
FV[file_versions table]
SS[system_settings table]
end
subgraph "External Services"
GD[Google Drive API]
GDA[Google Drive Direct]
end
WP --> DF
SP --> DF
DF --> SF
DF --> FV
DF --> SS
DF --> GD
DF --> GDA
```

**Diagram sources**
- [download-file/index.ts:1-131](file://supabase/functions/download-file/index.ts#L1-L131)
- [DownloadPage.jsx:1-158](file://web/src/pages/DownloadPage.jsx#L1-L158)
- [001_initial_schema.sql:55-122](file://supabase/migrations/001_initial_schema.sql#L55-L122)

**Section sources**
- [download-file/index.ts:1-131](file://supabase/functions/download-file/index.ts#L1-L131)
- [DownloadPage.jsx:1-158](file://web/src/pages/DownloadPage.jsx#L1-L158)
- [001_initial_schema.sql:55-122](file://supabase/migrations/001_initial_schema.sql#L55-L122)

## Core Components

### Edge Function Architecture
The download-file edge function implements a streamlined request processing pipeline:

1. **CORS Configuration**: Enables cross-origin requests for browser compatibility
2. **Request Validation**: Extracts and validates the share hash parameter
3. **Database Query**: Retrieves file metadata using the Supabase admin client
4. **Permission Verification**: Checks sharing status and system availability
5. **Google Drive Integration**: Attempts multiple download redirection strategies
6. **Error Handling**: Provides comprehensive error responses for various failure scenarios

### Authentication Flow
Unlike other edge functions, the download-file function operates without JWT verification, enabling anonymous access for public file downloads:

```mermaid
sequenceDiagram
participant Browser as "Browser"
participant EdgeFunc as "download-file"
participant Supabase as "Supabase DB"
participant GoogleDrive as "Google Drive"
Browser->>EdgeFunc : GET /functions/v1/download-file?hash={share_hash}
EdgeFunc->>EdgeFunc : Validate hash parameter
EdgeFunc->>Supabase : Query shared_files by unique_share_hash
Supabase-->>EdgeFunc : File metadata
EdgeFunc->>EdgeFunc : Check sharing_status
EdgeFunc->>EdgeFunc : Verify system_settings.downloads_enabled
EdgeFunc->>GoogleDrive : Fetch file metadata via API
GoogleDrive-->>EdgeFunc : webContentLink or error
EdgeFunc->>Browser : Redirect to Google Drive URL
Note over EdgeFunc,Browser : No JWT required for public downloads
```

**Diagram sources**
- [download-file/index.ts:9-129](file://supabase/functions/download-file/index.ts#L9-L129)
- [config.toml:16-17](file://supabase/config.toml#L16-L17)

**Section sources**
- [download-file/index.ts:1-131](file://supabase/functions/download-file/index.ts#L1-L131)
- [config.toml:16-17](file://supabase/config.toml#L16-L17)

## Architecture Overview

### System Integration Flow
The download system integrates multiple components working together:

```mermaid
flowchart TD
A[User Clicks Download Link] --> B[Frontend Validates Share Hash]
B --> C[Frontend Calls Edge Function]
C --> D[Edge Function Processes Request]
D --> E{Share Hash Valid?}
E --> |No| F[Return 404 Not Found]
E --> |Yes| G[Query Database for File Info]
G --> H{File Exists?}
H --> |No| F
H --> |Yes| I[Check Sharing Status]
I --> J{Status Private?}
J --> |Yes| K[Return 403 Access Denied]
J --> |No| L[Check System Availability]
L --> M{Downloads Enabled?}
M --> |No| N[Return 503 Service Unavailable]
M --> |Yes| O[Get Latest Google Drive File ID]
O --> P[Attempt Direct Download]
P --> Q{Direct Download Available?}
Q --> |Yes| R[Redirect to Google Drive]
Q --> |No| S[Use Alternative Download Method]
S --> R
T[User Receives File] --> U[Download Completes]
```

**Diagram sources**
- [download-file/index.ts:14-118](file://supabase/functions/download-file/index.ts#L14-L118)
- [DownloadPage.jsx:11-73](file://web/src/pages/DownloadPage.jsx#L11-L73)

### Database Schema Integration
The function interacts with three key database tables:

```mermaid
erDiagram
SHARED_FILES {
uuid id PK
uuid user_id FK
text google_drive_file_id
text file_name
bigint file_size
text mime_type
integer current_version_num
text unique_share_hash UK
text sharing_status
timestamptz created_at
}
FILE_VERSIONS {
uuid id PK
uuid file_id FK
text google_drive_file_id
integer version_number
timestamptz uploaded_at
}
SYSTEM_SETTINGS {
uuid id PK
text key UK
jsonb value
timestamptz updated_at
}
SHARED_FILES ||--o{ FILE_VERSIONS : contains
```

**Diagram sources**
- [001_initial_schema.sql:55-83](file://supabase/migrations/001_initial_schema.sql#L55-L83)
- [001_initial_schema.sql:107-122](file://supabase/migrations/001_initial_schema.sql#L107-L122)

**Section sources**
- [001_initial_schema.sql:55-122](file://supabase/migrations/001_initial_schema.sql#L55-L122)
- [download-file/index.ts:23-83](file://supabase/functions/download-file/index.ts#L23-L83)

## Detailed Component Analysis

### Edge Function Implementation

#### Request Processing Pipeline
The edge function follows a structured processing approach:

```mermaid
flowchart TD
Start([Function Entry]) --> OptionsCheck{"Is OPTIONS Request?"}
OptionsCheck --> |Yes| CorsResponse["Return CORS Headers"]
OptionsCheck --> |No| ExtractHash["Extract hash from URL"]
ExtractHash --> ValidateHash{"Hash Present?"}
ValidateHash --> |No| NotFound["Return 404 Response"]
ValidateHash --> |Yes| QueryDB["Query shared_files table"]
QueryDB --> DBResult{"File Found?"}
DBResult --> |No| NotFoundHTML["Return HTML 404 Page"]
DBResult --> |Yes| CheckStatus["Check sharing_status"]
CheckStatus --> IsPrivate{"Status = private?"}
IsPrivate --> |Yes| AccessDenied["Return HTML 403 Page"]
IsPrivate --> |No| CheckSystem["Check system_settings.downloads_enabled"]
CheckSystem --> SystemEnabled{"Downloads Enabled?"}
SystemEnabled --> |No| Maintenance["Return HTML 503 Page"]
SystemEnabled --> |Yes| GetDriveID["Get Latest Google Drive File ID"]
GetDriveID --> TryDirect["Try Direct Download"]
TryDirect --> DirectAvailable{"Direct Download Available?"}
DirectAvailable --> |Yes| Redirect["Redirect to Google Drive"]
DirectAvailable --> |No| Fallback["Use Fallback Download Method"]
Fallback --> Redirect
Redirect --> End([Function Exit])
NotFoundHTML --> End
AccessDenied --> End
Maintenance --> End
CorsResponse --> End
```

**Diagram sources**
- [download-file/index.ts:9-129](file://supabase/functions/download-file/index.ts#L9-L129)

#### Google Drive Integration Strategies
The function implements two primary download strategies:

1. **Direct Content Link Strategy**: Uses Google Drive API to fetch `webContentLink`
2. **Fallback Download Strategy**: Uses Google Drive's direct download endpoint

**Section sources**
- [download-file/index.ts:74-118](file://supabase/functions/download-file/index.ts#L74-L118)

### Frontend Integration

#### Download Page Workflow
The frontend implements comprehensive validation and user feedback:

```mermaid
sequenceDiagram
participant User as "User"
participant Page as "DownloadPage"
participant Supabase as "Supabase Client"
participant EdgeFunc as "download-file"
participant Browser as "Browser"
User->>Page : Navigate to /download/{hash}
Page->>Supabase : Validate share hash
Supabase-->>Page : File metadata
Page->>Page : Check sharing_status
Page->>Supabase : Check system_settings
Supabase-->>Page : System status
Page->>EdgeFunc : Call download function
EdgeFunc-->>Page : Redirect response
Page->>Browser : Redirect to download
Browser-->>User : File download starts
Note over Page,Browser : Real-time status updates
```

**Diagram sources**
- [DownloadPage.jsx:11-73](file://web/src/pages/DownloadPage.jsx#L11-L73)

**Section sources**
- [DownloadPage.jsx:1-158](file://web/src/pages/DownloadPage.jsx#L1-L158)

### Authentication and Security Model

#### Permission Verification Process
The system implements a multi-layered permission verification system:

```mermaid
flowchart TD
A[Download Request] --> B[Extract Share Hash]
B --> C[Query Database for File]
C --> D{File Found?}
D --> |No| E[Return 404]
D --> |Yes| F[Check Sharing Status]
F --> G{Status = public?}
G --> |No| H[Return 403]
G --> |Yes| I[Check System Settings]
I --> J{Downloads Enabled?}
J --> |No| K[Return 503]
J --> |Yes| L[Proceed to Download]
M[File Access Control] --> N[Row Level Security]
N --> O[Public Read Policy]
O --> P[Anonymous Access Allowed]
```

**Diagram sources**
- [download-file/index.ts:36-72](file://supabase/functions/download-file/index.ts#L36-L72)
- [001_initial_schema.sql:170-173](file://supabase/migrations/001_initial_schema.sql#L170-L173)

**Section sources**
- [download-file/index.ts:46-72](file://supabase/functions/download-file/index.ts#L46-L72)
- [001_initial_schema.sql:170-173](file://supabase/migrations/001_initial_schema.sql#L170-L173)

## Dependency Analysis

### External Dependencies
The download function relies on several external services:

```mermaid
graph LR
subgraph "Internal Dependencies"
A[Supabase Client]
B[Shared Files Table]
C[System Settings Table]
D[File Versions Table]
end
subgraph "External Dependencies"
E[Google Drive API]
F[Google Drive Direct]
G[CORS Headers]
end
A --> B
A --> C
A --> D
B --> E
B --> F
G --> Browser
```

**Diagram sources**
- [download-file/index.ts:24-107](file://supabase/functions/download-file/index.ts#L24-L107)

### Environment Configuration
The function requires specific environment variables:

| Variable | Purpose | Required |
|----------|---------|----------|
| SUPABASE_URL | Supabase project URL | Yes |
| SUPABASE_SERVICE_ROLE_KEY | Admin database access | Yes |
| GOOGLE_API_KEY | Google Drive API access | Yes |

**Section sources**
- [download-file/index.ts:24-27](file://supabase/functions/download-file/index.ts#L24-L27)
- [download-file/index.ts:102-104](file://supabase/functions/download-file/index.ts#L102-L104)

## Performance Considerations

### Optimization Strategies
1. **Database Query Optimization**: Single query with selective field retrieval
2. **Caching Strategy**: Minimal caching due to real-time nature
3. **Network Efficiency**: Direct redirect minimizes processing overhead
4. **Error Early Exit**: Immediate response for invalid requests

### Scalability Factors
- Edge function cold start latency
- Google Drive API response times
- Database connection pooling
- CORS preflight handling

## Troubleshooting Guide

### Common Error Scenarios

#### Missing Share Hash
**Symptoms**: Immediate 404 response
**Cause**: No hash parameter in URL
**Solution**: Verify share link contains valid hash parameter

#### File Not Found
**Symptoms**: HTML 404 page with "File Not Found" message
**Cause**: Non-existent or deleted file
**Solution**: Check file existence in database, verify unique_share_hash

#### Access Denied (Private Files)
**Symptoms**: HTML 403 page with "Access Denied" message
**Cause**: File sharing_status = private
**Solution**: Contact file owner for access, change sharing settings

#### System Maintenance
**Symptoms**: HTML 503 page with maintenance message
**Cause**: downloads_enabled = false
**Solution**: Wait for system maintenance completion

#### Google Drive Integration Issues
**Symptoms**: Redirect loop or download failure
**Cause**: Google Drive file accessibility issues
**Solution**: Verify file is publicly accessible, check Google Drive API status

### Debugging Techniques

#### Backend Debugging
1. **Console Logging**: Monitor function execution in Supabase logs
2. **Error Tracking**: Implement structured error responses
3. **Database Queries**: Verify SQL query execution and results
4. **Environment Variables**: Validate required configuration

#### Frontend Debugging
1. **Network Inspection**: Monitor download function calls
2. **Status Updates**: Track download progress states
3. **Error Handling**: Display meaningful error messages
4. **URL Validation**: Verify share hash correctness

**Section sources**
- [download-file/index.ts:120-128](file://supabase/functions/download-file/index.ts#L120-L128)
- [DownloadPage.jsx:66-70](file://web/src/pages/DownloadPage.jsx#L66-L70)

## Conclusion
The download-file edge function provides a robust, secure mechanism for handling public file downloads in the Neo Files Transfer system. Its architecture balances simplicity with comprehensive error handling, while leveraging Google Drive's public file access capabilities. The system's multi-layered permission verification ensures appropriate access control, and the dual-download strategy maximizes reliability across different file types and configurations.

The implementation demonstrates best practices for serverless file delivery, including proper CORS handling, structured error responses, and efficient database interactions. The frontend integration provides excellent user experience with real-time status updates and comprehensive error messaging.