# Live Streaming Implementation for Job Applications

## Overview
This document describes the live streaming feature that shows real-time screenshots of the application process, similar to sorce.jobs.

## Architecture

### Backend (Playwright Service)
- **SSE Endpoint**: `/stream/:sessionId` - Server-Sent Events endpoint for streaming
- **Streaming Functions**: 
  - `sendFrame(sessionId, frameData, metadata)` - Sends screenshot frames
  - `sendEvent(sessionId, eventType, data)` - Sends status events
- **Session Management**: `activeStreams` Map stores active SSE connections

### Flow
1. iOS app generates a unique `sessionId` (UUID)
2. iOS app opens SSE connection to `/stream/:sessionId`
3. iOS app calls `/automate` endpoint with `streamSessionId` parameter
4. Playwright service streams screenshots at key moments:
   - After navigation
   - During form filling (after each field)
   - After form submission
   - On completion
5. iOS app displays frames in real-time
6. Stream closes when automation completes

## Implementation Status

### ✅ Backend (Playwright Service)
- [x] SSE endpoint added
- [x] Helper functions for sending frames/events
- [ ] Streaming integrated into automation flow (in progress)
- [ ] Screenshot capture at key moments

### ⏳ iOS App
- [ ] SSE client implementation
- [ ] Real-time frame display
- [ ] Session ID generation
- [ ] UI updates for live stream

## Next Steps
1. Complete streaming integration in Playwright service
2. Implement SSE client in iOS app
3. Update AutoApplyProgressView to show live stream
4. Test end-to-end streaming

