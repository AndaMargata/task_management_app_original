# Task Management App — Project Documentation

**Course:** Mobile Application Development  
**Platform:** Cross-Platform (Flutter / Dart)  
**IDE:** Visual Studio Code  
**Architecture:** MVVM (Model-View-ViewModel)  
**Backend:** Firebase (Authentication, Cloud Firestore) + Backblaze B2 (Media Storage)

---

## Table of Contents

1. [Project Overview](#1-project-overview)  
2. [Features & Functional Modules](#2-features--functional-modules)  
3. [Technical Stack & Dependencies](#3-technical-stack--dependencies)  
4. [Architecture & Design Pattern (MVVM)](#4-architecture--design-pattern-mvvm)  
5. [Project Structure](#5-project-structure)  
6. [Data Models](#6-data-models)  
7. [Services Layer](#7-services-layer)  
8. [ViewModels](#8-viewmodels)  
9. [Screens & UI](#9-screens--ui)  
10. [User Authentication](#10-user-authentication)  
11. [Task Management Module](#11-task-management-module)  
12. [Real-Time Chat / Messaging Module](#12-real-time-chat--messaging-module)  
13. [Media Sharing Module](#13-media-sharing-module)  
14. [API Integration](#14-api-integration)  
15. [Notifications](#15-notifications)  
16. [Responsive UI/UX](#16-responsive-uiux)  
17. [Firebase Security Rules](#17-firebase-security-rules)  
18. [Testing](#18-testing)  
19. [Environment Configuration](#19-environment-configuration)  
20. [How to Run the Project](#20-how-to-run-the-project)  
21. [Requirements Mapping](#21-requirements-mapping)

---

## 1. Project Overview

The **Task Management App** is a cross-platform mobile application built with **Flutter** that enables users to manage personal and team tasks, communicate via real-time chat (with rich media support), and stay motivated through inspirational quotes fetched from an external API.

The application targets collaborative productivity with features including:

- Email-based user authentication with **email verification** and **password reset**.
- Full task lifecycle management with statuses (To Do → In Progress → Testing → Complete).
- **Admin role** system allowing designated users to assign tasks to team members and manage user roles.
- **Real-time 1-on-1 messaging** with support for text, images, videos, and voice messages.
- **Local push notifications** for chat messages and task events.
- Integration with the **API Ninjas Quotes API** for motivational quotes.
- Responsive, Material Design 3 UI that adapts to all screen sizes.

---

## 2. Features & Functional Modules

The application implements **five core functional modules**, exceeding the minimum requirement of three:

### Module 1 — Task / To-Do Management
- Create, edit, and delete tasks with title, description, priority, difficulty, deadline, and estimated duration.
- Four-stage workflow: **To Do → In Progress → Testing → Complete**.
- Filter tasks by status (Total Active, Done, Pending, Testing).
- Task comments sub-system with optional image attachments.
- Overdue task detection with visual indicators.

### Module 2 — Real-Time Chat / Messaging
- 1-on-1 real-time conversations powered by Firestore snapshots.
- User search by name or email prefix.
- Unread message badges and conversation list with relative timestamps.
- Date separators within conversations.

### Module 3 — Media Sharing (Photos, Videos, Audio)
- Send and receive **images** (gallery or camera).
- Send and receive **videos** (gallery-sourced, up to 3 minutes).
- Record and send **voice messages** with duration tracking.
- Full-screen image viewer with pinch-to-zoom (InteractiveViewer).
- Inline video playback within chat bubbles.
- All media files uploaded to **Backblaze B2** cloud storage with public download URLs.

### Module 4 — Admin Dashboard / User Management
- Admin users can assign tasks to any registered user.
- Admin panel to promote/demote users between `admin` and `member` roles.
- Admin badge shown in the UI when the current user is an admin.

### Module 5 — API Integration (Quotes Service)
- Integration with the **API Ninjas Quotes REST API** (`api.api-ninjas.com`).
- Fetches random motivational quotes with categories (`success`, `courage`).
- "Quote of the Day" feature displayed via a dialog on the task screen.

---

## 3. Technical Stack & Dependencies

### Core Framework
| Technology | Version | Purpose |
|---|---|---|
| Flutter | SDK ^3.11.0 | Cross-platform UI framework |
| Dart | ^3.11.0 | Programming language |

### Firebase Services
| Package | Purpose |
|---|---|
| `firebase_core` ^2.8.0 | Firebase initialisation |
| `firebase_auth` ^4.6.0 | Email/password authentication |
| `cloud_firestore` ^4.17.5 | Real-time NoSQL database |

### Networking & API
| Package | Purpose |
|---|---|
| `http` ^1.6.0 | REST API calls (Quotes API, Backblaze B2 API) |
| `flutter_dotenv` ^5.0.2 | Environment variable management (.env) |

### State Management
| Package | Purpose |
|---|---|
| `provider` ^6.1.5+1 | ChangeNotifier-based state management (MVVM) |

### Media
| Package | Purpose |
|---|---|
| `image_picker` ^1.0.7 | Pick images/videos from gallery or camera |
| `record` ^6.0.0 | Audio recording (voice messages) |
| `audioplayers` ^6.1.0 | Audio playback |
| `video_player` ^2.8.3 | Inline video playback |
| `cached_network_image` ^3.3.1 | Cached network images with placeholders |

### Notifications
| Package | Purpose |
|---|---|
| `flutter_local_notifications` ^20.1.0 | Local push notifications |

### Utilities
| Package | Purpose |
|---|---|
| `intl` ^0.19.0 | Date/time formatting |
| `uuid` ^4.3.3 | Unique ID generation for file uploads |
| `path_provider` ^2.1.2 | Temporary directory access for recordings |

---

## 4. Architecture & Design Pattern (MVVM)

The application follows the **Model-View-ViewModel (MVVM)** architecture pattern for clean separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                        VIEW (Screens)                    │
│  LoginScreen, TaskListScreen, ChatScreen, etc.           │
│  - Renders UI based on ViewModel state                   │
│  - Sends user actions to ViewModel                       │
└────────────────────┬────────────────────────────────────┘
                     │ Watches via Provider (ChangeNotifier)
┌────────────────────▼────────────────────────────────────┐
│                    VIEWMODEL                             │
│  TaskViewmodel, ChatViewmodel                            │
│  - Holds application state                               │
│  - Orchestrates business logic                           │
│  - Calls Services for data operations                    │
│  - Notifies Views via notifyListeners()                  │
└────────────────────┬────────────────────────────────────┘
                     │ Calls
┌────────────────────▼────────────────────────────────────┐
│                    SERVICES                              │
│  AuthService, ChatService, StorageService,               │
│  NotificationService, QuotesService                      │
│  - Direct Firebase / API interactions                    │
│  - Stateless utility classes (static methods)            │
└────────────────────┬────────────────────────────────────┘
                     │ Reads / Writes
┌────────────────────▼────────────────────────────────────┐
│                    MODELS                                │
│  Task, ChatMessage, ChatUser, Conversation, TaskComment  │
│  - Pure data classes with toMap() / fromMap()            │
│  - Firestore serialization/deserialization               │
└─────────────────────────────────────────────────────────┘
```

**State Management:** The `provider` package is used to inject `TaskViewmodel` and `ChatViewmodel` at the root of the widget tree via `MultiProvider`. Screens use `context.watch<T>()` for reactive rebuilds and `context.read<T>()` for fire-and-forget operations.

---

## 5. Project Structure

```
lib/
├── main.dart                         # App entry point, theme, AuthGate, HomeScreen
├── firebase_options.dart             # Auto-generated Firebase configuration
│
├── models/                           # Data classes (M in MVVM)
│   ├── task.dart                     # Task, TaskStatus, TaskComment
│   ├── chat_message.dart             # ChatMessage, MessageType
│   ├── chat_user.dart                # ChatUser (user profiles)
│   └── conversation.dart             # Conversation (chat threads)
│
├── viewmodels/                       # Business logic (VM in MVVM)
│   ├── task_viewmodel.dart           # Task CRUD, comments, assignment
│   └── chat_viewmodel.dart           # Conversations, messages, notifications
│
├── services/                         # Data access layer
│   ├── auth_service.dart             # Firebase Auth wrapper
│   ├── chat_service.dart             # Firestore chat operations + user profiles
│   ├── notification_service.dart     # Local notification handling
│   ├── quotes_service.dart           # External API integration (REST)
│   └── storage_service.dart          # Backblaze B2 file upload/delete
│
├── screens/                          # UI layer (V in MVVM)
│   ├── auth/
│   │   ├── login_screen.dart         # Login form + forgot password dialog
│   │   ├── signup_screen.dart        # Registration form (first/last name, email, password)
│   │   └── email_verification_screen.dart  # Email verification gate
│   ├── task/
│   │   ├── task_list_screen.dart     # Main task dashboard with filters & stat chips
│   │   └── assign_task_screen.dart   # Admin: assign task to a user
│   ├── chat/
│   │   ├── chat_list_screen.dart     # Conversation list with unread badges
│   │   ├── chat_screen.dart          # 1-on-1 chat with media support
│   │   └── user_search_screen.dart   # Find users to start new conversations
│   ├── admin/
│   │   └── manage_users_screen.dart  # Admin: promote/demote user roles
│   └── common/
│       └── full_screen_image_viewer.dart  # Zoomable full-screen image viewer
│
├── utils/                            # Shared utilities
│   ├── responsive.dart               # Responsive scaling helpers
│   └── logout_helper.dart            # Reusable logout with loading dialog
│
test/
└── widget_test.dart                  # Unit tests for Task, Conversation, ChatMessage models
```

---

## 6. Data Models

### 6.1 Task (`models/task.dart`)

Represents a task/to-do item stored in the Firestore `tasks` collection.

| Field | Type | Description |
|---|---|---|
| `id` | String | Firestore document ID |
| `title` | String | Task title |
| `description` | String | Task description |
| `isCompleted` | bool | Whether the task is marked as done |
| `dueDate` | DateTime | Date the task was created |
| `deadline` | DateTime? | Optional deadline with overdue detection |
| `estimatedMinutes` | int? | Estimated duration in minutes |
| `priority` | String | `'normal'` or `'important'` |
| `difficulty` | String | `'easy'`, `'medium'`, or `'hard'` |
| `status` | String | Workflow state: `'todo'`, `'in_progress'`, `'testing'`, `'complete'` |
| `assignedTo` | String? | UID of the user the task is assigned to |
| `assignedToName` | String? | Display name of the assignee |
| `assignedBy` | String? | UID of the admin who assigned the task |
| `assignedByName` | String? | Display name of the assigner |
| `ownerUid` | String | UID of the task creator/owner |

**Helper Methods:**
- `isOverdue` — returns `true` if the deadline has passed and the task is not completed.
- `estimatedDurationLabel` — human-readable duration string (e.g., "1h 35m").
- `copyWith()` — immutable update pattern.
- `toMap()` / `fromMap()` — Firestore serialization.

### TaskStatus
Static constants for the four workflow states: `todo`, `inProgress`, `testing`, `complete`.

### TaskComment
Sub-document stored in `tasks/{taskId}/comments/` with fields: `authorUid`, `authorName`, `text`, `createdAt`, and optional `imageUrl`.

### 6.2 ChatMessage (`models/chat_message.dart`)

Represents a single message in a conversation.

| Field | Type | Description |
|---|---|---|
| `id` | String | Document ID |
| `senderId` | String | UID of the sender |
| `text` | String | Text content (empty for media-only messages) |
| `timestamp` | DateTime? | Server timestamp |
| `type` | String | `'text'`, `'image'`, `'video'`, or `'audio'` |
| `mediaUrl` | String? | Download URL for media |
| `mediaDuration` | int? | Duration in seconds (audio/video) |

**Helper Getters:** `isText`, `isImage`, `isVideo`, `isAudio`, `hasMedia`.

### 6.3 ChatUser (`models/chat_user.dart`)

Represents a user profile stored in the Firestore `users` collection.

| Field | Type | Description |
|---|---|---|
| `uid` | String | Firebase Auth UID |
| `email` | String | User email |
| `displayName` | String | Display name |
| `firstName` | String | First name |
| `lastName` | String | Last name |
| `role` | String | `'admin'` or `'member'` |
| `createdAt` | DateTime? | Account creation timestamp |

**Helper Getters:** `isAdmin`, `fullName`.

### 6.4 Conversation (`models/conversation.dart`)

Represents a 1-on-1 chat thread.

| Field | Type | Description |
|---|---|---|
| `id` | String | Deterministic ID: `{uid1}_{uid2}` (sorted) |
| `participants` | List\<String\> | Both user UIDs |
| `participantNames` | Map\<String, String\> | UID → display name |
| `participantEmails` | Map\<String, String\> | UID → email |
| `lastMessage` | String | Preview of the most recent message |
| `lastMessageTime` | DateTime? | Timestamp of the last message |
| `lastMessageSenderId` | String | UID of last message sender |
| `unread` | Map\<String, int\> | UID → unread count |

---

## 7. Services Layer

All services are implemented as **static utility classes**, providing a clean data access layer.

### 7.1 AuthService (`services/auth_service.dart`)

Wraps `FirebaseAuth` for all authentication operations.

| Method | Description |
|---|---|
| `signUp(email, password, {firstName, lastName})` | Creates account, sets display name, sends verification email |
| `signIn(email, password)` | Email/password sign-in |
| `signOut()` | Signs out the current user |
| `sendPasswordResetEmail(email)` | Sends password reset email |
| `sendVerificationEmail()` | Resends email verification link |
| `reloadCurrentUser()` | Reloads user to check verification status |
| `authStateChanges` | Stream of auth state (used by `AuthGate`) |

### 7.2 ChatService (`services/chat_service.dart`)

Handles all Firestore operations for users, conversations, and messages.

**User Profile:**
- `ensureUserProfile()` — creates/updates user doc at `users/{uid}` (preserves existing admin role).
- `getUserProfile()` — fetches a single user profile.
- `setUserRole()` — changes a user's role (admin/member).
- `searchUsers()` — prefix search by email or display name.
- `listAllUsers()` — returns all users except the current user.

**Conversations:**
- `conversationsStream()` — real-time stream of conversations for a user, sorted by last message time.
- `createConversation()` — creates a new 1-on-1 conversation with deterministic ID.

**Messages:**
- `messagesStream()` — real-time ordered stream of messages in a conversation.
- `sendMessage()` — batched write: creates message document + updates conversation header (last message, unread count).
- `markConversationAsRead()` — resets unread counter for a user.

### 7.3 NotificationService (`services/notification_service.dart`)

Manages **local push notifications** using `flutter_local_notifications`.

| Method | Description |
|---|---|
| `init()` | Initialises notification plugin, requests Android 13+ permissions |
| `setActiveConversation(id)` | Suppresses notifications for the currently viewed conversation |
| `showMessageNotification()` | Fires a local notification for incoming chat messages |
| `showTaskNotification()` | Fires a local notification for task assignments and status changes |

**Notification Channels (Android):**
- `chat_messages` — Chat message notifications (high priority).
- `task_updates` — Task assignment and status change notifications (high priority).

### 7.4 QuotesService (`services/quotes_service.dart`)

Integrates with the **API Ninjas Quotes REST API**.

- Endpoint: `https://api.api-ninjas.com/v2/randomquotes` (fallback: `/v2/quotes`).
- Authentication via `X-Api-Key` header (stored in `.env`).
- Returns a formatted string: `"quote text\n— author"`.
- Supports category filtering (default: `success`, `courage`).
- 12-second request timeout.

### 7.5 StorageService (`services/storage_service.dart`)

Handles file uploads to **Backblaze B2** cloud storage.

**Upload Flow:**
1. Authenticates with B2 API using `b2_authorize_account` (caches token for 23 hours).
2. Obtains an upload URL via `b2_get_upload_url`.
3. Reads file bytes and sends them with correct MIME type.
4. Returns a public download URL: `{downloadUrl}/file/{bucketName}/{folder}/{userId}/{uuid}.{ext}`.

**Supported MIME Types:** JPEG, PNG, GIF, WebP, MP4, MOV, M4A, AAC, WAV.

Also supports file deletion via `b2_list_file_names` + `b2_delete_file_version`.

---

## 8. ViewModels

### 8.1 TaskViewmodel (`viewmodels/task_viewmodel.dart`)

Central state holder for all task-related operations.

**State:**
- `_ownTasks` — tasks owned by the current user.
- `_assignedTasks` — tasks assigned to the current user by others.
- `tasks` — merged, de-duplicated list of both.
- `_currentUserProfile` — the current user's `ChatUser` profile (for role checking).

**Key Methods:**

| Method | Description |
|---|---|
| `bindToUser(userId)` | Subscribes to Firestore streams for owned and assigned tasks |
| `unbindUser()` | Cancels all subscriptions and clears state |
| `addTask(...)` | Creates a new task in Firestore |
| `updateTask(...)` | Updates task fields (title, description, deadline, etc.) |
| `deleteTask(id)` | Deletes a task |
| `toggleTaskStatus(id)` | Toggles `isCompleted` flag |
| `updateTaskStatus(id, status)` | Changes workflow status + fires notification |
| `addComment(taskId, text, {imageUrl})` | Adds a comment to a task (with optional photo) |
| `clearComments(taskId)` | Batch-deletes all comments on a task |
| `commentsStream(taskId)` | Real-time stream of comments |
| `assignTask(...)` | Admin: creates a task assigned to another user + fires notification |
| `refreshProfile()` | Reloads user profile (e.g. after role change) |

### 8.2 ChatViewmodel (`viewmodels/chat_viewmodel.dart`)

Central state holder for all chat-related operations.

**State:**
- `_conversations` — real-time list of conversations.
- `_currentMessages` — messages for the active conversation.
- `_activeConversationId` — currently viewed conversation (suppresses notifications).
- `totalUnreadCount` — total unread messages across all conversations.

**Key Methods:**

| Method | Description |
|---|---|
| `bindToUser(userId)` | Subscribes to conversation stream + fires notifications for new messages |
| `unbindUser()` | Cancels all subscriptions |
| `openConversation(id)` | Subscribes to message stream, marks conversation as read |
| `closeConversation()` | Unsubscribes from message stream |
| `sendMessage(text, {type, mediaUrl, mediaDuration})` | Sends text or media message |
| `startConversation(otherUser)` | Opens existing or creates new conversation |
| `searchUsers(query)` | Delegates to `ChatService.searchUsers()` |
| `listAllUsers()` | Delegates to `ChatService.listAllUsers()` |

---

## 9. Screens & UI

### Screen Map

```
AuthGate (StreamBuilder on Firebase Auth state)
├── LoginScreen              [Not logged in]
├── EmailVerificationScreen  [Logged in but email not verified]
└── HomeScreen               [Logged in and verified]
    ├── Tab 0: TaskListScreen
    │   ├── _TaskEditorSheet (modal bottom sheet for add/edit)
    │   ├── _ExpandableTaskItem (task card with comments)
    │   ├── AssignTaskScreen (admin only, push navigation)
    │   └── ManageUsersScreen (admin only, push navigation)
    └── Tab 1: ChatListScreen
        ├── UserSearchScreen (new message, push navigation)
        └── ChatScreen (1-on-1 conversation, push navigation)
            └── FullScreenImageViewer (image zoom, push navigation)
```

---

## 10. User Authentication

### Login (`screens/auth/login_screen.dart`)
- Email and password fields with validation.
- Real-time field-level error messages for invalid email, wrong password, etc.
- **"Forgot Password"** dialog: accepts email, sends Firebase password-reset email, with resend capability.
- Animated entrance (fade + slide) for polished UX.
- Navigate to `SignupScreen` for new accounts.

### Signup (`screens/auth/signup_screen.dart`)
- Collects: **First Name**, **Last Name**, **Email**, **Password**, **Confirm Password**.
- Password minimum 6 characters; confirm must match.
- On success, automatically sends verification email and returns to login flow.
- Error handling for weak passwords and duplicate emails.

### Email Verification (`screens/auth/email_verification_screen.dart`)
- Shown when the user is logged in but email is **not yet verified**.
- Auto-sends verification email on screen load.
- "Resend Email" button for re-sending.
- "I Have Verified" button reloads the user; `AuthGate` detects verification and advances to `HomeScreen`.
- Animated pulsing email icon for visual engagement.

### Auth Gate (`main.dart` → `AuthGate`)
- Uses `StreamBuilder<User?>` on `AuthService.authStateChanges`.
- Routes to:
  - `LoginScreen` when not authenticated.
  - `EmailVerificationScreen` when authenticated but not verified.
  - `HomeScreen` when authenticated and verified.
- Calls `ensureUserProfile()` to create/update the Firestore user document on every authentication.
- Binds `TaskViewmodel` and `ChatViewmodel` to the current user.

---

## 11. Task Management Module

### Task List Screen (`screens/task/task_list_screen.dart`)

**Dashboard Header:**
- Gradient background with "My Tasks" title.
- Admin badge shown for admin users.
- Action buttons: Add Task (+), Quote of the Day, Sign Out.
- Admin popup menu: Assign Task, Manage Users.

**Filter Stat Chips:**
- Four horizontally scrollable chips: **Total**, **Done**, **Pending**, **Testing**.
- Each shows the count and highlights when selected.
- Tapping a chip filters the task list.

**Quote Card:**
- Inline motivational quote card at the top of the task list (fetched from API Ninjas).

**Task Cards (Expandable):**
- Collapsed: title, priority badge, difficulty badge, deadline, estimated duration, status chip, assigned-to info.
- Expanded: description, comments section, comment input field.
- **Task Actions:**
  - Swipe/tap to edit (opens bottom sheet editor).
  - Swipe/tap to delete (confirmation dialog).
  - Status change via dropdown (To Do → In Progress → Testing → Complete).
  - Toggle completion.

**Task Editor (Bottom Sheet):**
- Title and description text fields.
- Deadline picker (date + time).
- Estimated duration chooser (None, 15m, 30m, 1h, 2h, 4h, 8h).
- Priority selector (Normal / Important).
- Difficulty selector (Easy / Medium / Hard).
- Works for both creating new tasks and editing existing ones.

**Task Comments:**
- Real-time comment stream displayed under expanded task cards.
- Text input + optional photo attachment via image picker.
- Photos uploaded to Backblaze B2 and displayed inline as cached network images.
- Tap on comment image → full-screen zoomable viewer.

### Assign Task Screen (`screens/task/assign_task_screen.dart`)
- **Admin-only** screen accessible from the task header popup menu.
- User picker listing all registered users.
- Task form: title, description, deadline, estimated duration, priority, difficulty.
- On submit, creates a task in Firestore assigned to the selected user and fires a local notification.

---

## 12. Real-Time Chat / Messaging Module

### Chat List Screen (`screens/chat/chat_list_screen.dart`)
- Gradient header with "Messages" title and sign-out button.
- Real-time conversation list sorted by last message time.
- Each card shows: avatar, name, last message preview, relative time, unread badge.
- Highlighted background for conversations with unread messages.
- FAB "New Chat" → navigates to `UserSearchScreen`.

### User Search Screen (`screens/chat/user_search_screen.dart`)
- Search bar with debounced (400ms) prefix search by name or email.
- Default: shows all registered users.
- Tapping a user creates (or opens existing) conversation and navigates to `ChatScreen`.

### Chat Screen (`screens/chat/chat_screen.dart`)
- Real-time message stream, newest at bottom (reverse list).
- Date separators between messages from different days.
- Auto-scrolls to bottom on new messages.
- Marks conversation as read when opened.

**Message Types Supported:**
1. **Text** — standard text bubble.
2. **Image** — thumbnail in bubble, tap for full-screen viewer.
3. **Video** — inline video player widget.
4. **Audio/Voice** — playback controls with duration display.

**Input Bar:**
- Text field + send button.
- Attachment button → bottom sheet with options: Gallery, Camera, Video.
- Mic button for voice recording (long press to record, controls to send/cancel).
- Upload progress bar shown during media upload.

**Voice Recording:**
- Uses `record` package with AAC-LC encoder.
- Real-time duration counter during recording.
- Cancel/Send controls while recording.
- Uploaded as `.m4a` to Backblaze B2.

---

## 13. Media Sharing Module

### Upload Pipeline
1. User picks media via `image_picker` (images/videos) or records via `record` (voice).
2. `StorageService.uploadFile()` authenticates with Backblaze B2 API.
3. File bytes are uploaded with unique path: `{folder}/{userId}/{uuid}.{ext}`.
4. Public download URL is returned.
5. URL is stored in Firestore message/comment document.
6. On display, `CachedNetworkImage` handles caching and placeholder rendering.

### Supported Media Types
| Type | Source | Format | Max Size/Duration |
|---|---|---|---|
| Photo | Gallery or Camera | JPEG (quality 70, max 1920px) | — |
| Video | Gallery | MP4 | 3 minutes |
| Voice | Microphone | M4A (AAC-LC) | Unlimited |

### Full-Screen Image Viewer (`screens/common/full_screen_image_viewer.dart`)
- Black background with `InteractiveViewer` (pinch-to-zoom, 0.5× – 4.0×).
- Optional `Hero` animation tag for smooth transitions.
- Error state for failed image loads.

---

## 14. API Integration

### API Ninjas — Quotes API

| Detail | Value |
|---|---|
| **Provider** | API Ninjas (https://api-ninjas.com) |
| **Endpoint** | `GET https://api.api-ninjas.com/v2/randomquotes` |
| **Fallback** | `GET https://api.api-ninjas.com/v2/quotes` |
| **Auth** | API key via `X-Api-Key` header |
| **Categories** | `success`, `courage` |
| **Timeout** | 12 seconds |
| **Response** | JSON array with `quote` and `author` fields |

**Implementation:** `QuotesService.fetchQuote()` in `services/quotes_service.dart`.

**Usage in UI:** The "Quote of the Day" button on the task screen calls this service and shows the result in an `AlertDialog`.

### Backblaze B2 — Cloud Storage REST API

| Detail | Value |
|---|---|
| **Provider** | Backblaze (https://www.backblaze.com/b2/) |
| **Auth Endpoint** | `GET https://api.backblazeb2.com/b2api/v2/b2_authorize_account` |
| **Upload Endpoints** | `b2_get_upload_url`, direct upload via returned URL |
| **Delete Endpoints** | `b2_list_file_names`, `b2_delete_file_version` |
| **Auth** | Basic auth (Key ID + Application Key from `.env`) |
| **Token Caching** | 23 hours |

**Implementation:** `StorageService` in `services/storage_service.dart`.

---

## 15. Notifications

The app implements **local push notifications** for two event categories:

### Chat Message Notifications
- Triggered when a new message arrives in a conversation the user is **not** currently viewing.
- Shows the sender's name as the title and message preview as the body.
- Tapping the notification can route to the conversation (via payload).
- **Suppression:** Notifications are suppressed for the actively viewed conversation (`setActiveConversation`).

### Task Notifications
- **Task Assignment:** "You've been assigned to "{title}" by {admin name}".
- **Status Change:** ""{title}" moved to {new status}".
- Both use the `task_updates` notification channel.

### Android Configuration
- Two notification channels: `chat_messages` and `task_updates`.
- Both set to `Importance.high` and `Priority.high`.
- Android 13+ `POST_NOTIFICATIONS` permission requested at startup.

---

## 16. Responsive UI/UX

### Material Design 3 Theme (`main.dart`)
- `ColorScheme.fromSeed(seedColor: Colors.indigo)` ensures consistent theming.
- Custom theme for: `AppBar`, `Card`, `InputDecoration`, `Button`, `NavigationBar`, `SnackBar`, `Dialog`.
- Rounded corners (16–28px radius) throughout the app.

### Responsive Utility (`utils/responsive.dart`)
A `Responsive` helper class scales dimensions based on a design baseline of **393 × 852 dp** (standard phone):

| Method | Purpose |
|---|---|
| `s(value)` | Scale spacing/padding by screen width |
| `fs(value)` | Scale font size (dampened for tablets) |
| `icon(value)` | Scale icon size |
| `h(value)` | Scale by screen height |
| `maxFormWidth` | Constrains form width on wide screens (max 520dp) |
| `isCompact` | True for screens < 360dp |
| `isWide` | True for screens ≥ 600dp (tablets) |

### UI Design Highlights
- **Gradient headers** on all main screens (login, signup, verification, tasks, chat).
- **Animated transitions:** `FadeTransition`, `SlideTransition`, `TweenAnimationBuilder` for cards and list items.
- **Bottom sheet** for task editing (keeps context while editing).
- **Navigation Bar** with unread badge on the Chat tab.
- **Empty states** with icons and helpful text for empty lists.
- **Loading indicators** throughout (circular progress, linear progress for uploads).

---

## 17. Firebase Security Rules

The Firestore security rules (`firestore.rules`) enforce authentication:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null;
    }
    match /tasks/{taskId} {
      allow read, create, update, delete: if request.auth != null;
      match /comments/{commentId} {
        allow read, create, delete: if request.auth != null;
      }
    }
    match /conversations/{convoId} {
      allow read, write: if request.auth != null;
      allow create: if request.auth != null;
      match /messages/{msgId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

All operations require the user to be **authenticated** (`request.auth != null`).

---

## 18. Testing

### Unit Tests (`test/widget_test.dart`)

The project includes **unit tests** for all three data models, verifying serialization, business logic, and helper methods.

#### Task Model Tests (5 tests)
| Test | Verifies |
|---|---|
| `TaskStatus.label maps every known status` | All four status labels + fallback for unknown status |
| `estimatedDurationLabel formats correctly` | Duration formatting: "45m", "1h", "1h 35m", empty string |
| `isOverdue is true when deadline has passed` | Overdue detection; completed tasks are not overdue |
| `toMap / fromMap roundtrip preserves fields` | Full serialization/deserialization preserves all fields |
| `copyWith overrides selected fields` | Immutable copy only changes specified fields |

#### Conversation Model Tests (2 tests)
| Test | Verifies |
|---|---|
| `helpers return correct other-participant info` | `unreadCountFor()`, `otherParticipantName()`, `otherParticipantEmail()` |
| `fromMap parses Firestore document` | Parses Firestore `Timestamp`, unread map, strings |

#### ChatMessage Model Tests (1 test)
| Test | Verifies |
|---|---|
| `type helpers work for media messages` | `isImage`, `isText`, `hasMedia` getters for different message types |

**Total: 8 unit tests across 3 model test groups.**

---

## 19. Environment Configuration

The app uses a **`.env`** file (loaded via `flutter_dotenv`) for sensitive configuration:

```env
API_NINJAS_KEY=<your-api-ninjas-key>
B2_KEY_ID=<your-backblaze-b2-key-id>
B2_APP_KEY=<your-backblaze-b2-application-key>
```

| Variable | Purpose |
|---|---|
| `API_NINJAS_KEY` | Authentication key for the API Ninjas Quotes API |
| `B2_KEY_ID` | Backblaze B2 key ID for cloud storage |
| `B2_APP_KEY` | Backblaze B2 application key |

The `.env` file is declared as a Flutter asset in `pubspec.yaml`.

Firebase configuration is auto-generated in `firebase_options.dart`.

---

## 20. How to Run the Project

### Prerequisites
- Flutter SDK ^3.11.0 installed and configured.
- Android Studio or VS Code with Flutter extensions.
- A Firebase project with Authentication and Cloud Firestore enabled.
- A Backblaze B2 bucket (public) for media storage.
- An API Ninjas account/key for the Quotes API.

### Steps

1. **Clone the repository** and navigate to the project directory.

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Create a `.env` file** in the project root with the required keys:
   ```env
   API_NINJAS_KEY=your_api_key_here
   B2_KEY_ID=your_b2_key_id
   B2_APP_KEY=your_b2_app_key
   ```

4. **Configure Firebase:**
   - Ensure `firebase_options.dart` and `google-services.json` (Android) are in place.
   - Enable Email/Password authentication in the Firebase Console.
   - Create Firestore database and deploy security rules.

5. **Run the app:**
   ```bash
   flutter run
   ```

6. **Run tests:**
   ```bash
   flutter test
   ```

---

## 21. Requirements Mapping

This table maps each mandatory project requirement to its implementation in the app:

### Mandatory Functional Requirements

| # | Requirement | Implementation | Files |
|---|---|---|---|
| 1 | **User Authentication** | Email/password login and signup via Firebase Auth | `auth_service.dart`, `login_screen.dart`, `signup_screen.dart` |
| 1a | Login/Signup (email) | Full email-based auth flow with form validation | `login_screen.dart`, `signup_screen.dart` |
| 1b | Email Verification | Automatic verification email on signup; verification gate screen | `email_verification_screen.dart`, `auth_service.dart` |
| 1c | Forgot Password | "Forgot Password" dialog sends Firebase reset email | `login_screen.dart` (`_openForgotPasswordDialog`) |
| 2 | **Core Feature Set (3+ modules)** | **5 modules:** Tasks, Chat, Media Sharing, Admin Dashboard, API Quotes | See Sections 11–14 |
| 2a | Task/To-Do Management | Full CRUD, 4-stage workflow, filters, comments, assignment | `task_list_screen.dart`, `task_viewmodel.dart` |
| 2b | Messaging/Chat | Real-time 1-on-1 chat with Firestore, user search, unread counts | `chat_screen.dart`, `chat_viewmodel.dart`, `chat_service.dart` |
| 2c | Media Sharing | Photo, video, and voice message sharing via B2 storage | `storage_service.dart`, `chat_screen.dart` |
| 3 | **API Integration** | **API Ninjas Quotes REST API** for motivational quotes | `quotes_service.dart`, `task_list_screen.dart` |
| 3 (bonus) | Additional API | **Backblaze B2 REST API** for cloud file storage | `storage_service.dart` |
| 4 | **Responsive UI/UX** | Material 3 design, responsive scaling, gradient themes, animations | `responsive.dart`, `main.dart`, all screens |
| 5 | **Notifications** | Local push notifications for chat messages and task events | `notification_service.dart` |

### Technical Requirements

| Requirement | Implementation |
|---|---|
| **Platform** | Cross-platform — Flutter (Dart) |
| **Tools** | Visual Studio Code |
| **Architecture** | MVVM with Provider for state management |
| **Testing** | 8 unit tests across 3 model groups (Task, Conversation, ChatMessage) |

---

## Firestore Database Schema

```
Firestore Root
├── users/
│   └── {userId}
│       ├── email: string
│       ├── displayName: string
│       ├── firstName: string
│       ├── lastName: string
│       ├── role: "admin" | "member"
│       ├── searchName: string (lowercase)
│       ├── searchEmail: string (lowercase)
│       └── createdAt: timestamp
│
├── tasks/
│   └── {taskId}
│       ├── id: string
│       ├── title: string
│       ├── description: string
│       ├── isCompleted: boolean
│       ├── status: "todo" | "in_progress" | "testing" | "complete"
│       ├── dueDate: timestamp
│       ├── deadline: timestamp (optional)
│       ├── estimatedMinutes: number (optional)
│       ├── priority: "normal" | "important"
│       ├── difficulty: "easy" | "medium" | "hard"
│       ├── ownerUid: string
│       ├── assignedTo: string (optional)
│       ├── assignedToName: string (optional)
│       ├── assignedBy: string (optional)
│       ├── assignedByName: string (optional)
│       ├── createdAt: timestamp
│       └── comments/ (sub-collection)
│           └── {commentId}
│               ├── authorUid: string
│               ├── authorName: string
│               ├── text: string
│               ├── imageUrl: string (optional)
│               └── createdAt: timestamp
│
└── conversations/
    └── {convoId}  (deterministic: "{uid1}_{uid2}" sorted)
        ├── participants: [string, string]
        ├── participantNames: {uid: name}
        ├── participantEmails: {uid: email}
        ├── lastMessage: string
        ├── lastMessageTime: timestamp
        ├── lastMessageSenderId: string
        ├── unread: {uid: number}
        └── messages/ (sub-collection)
            └── {msgId}
                ├── senderId: string
                ├── text: string
                ├── type: "text" | "image" | "video" | "audio"
                ├── mediaUrl: string (optional)
                ├── mediaDuration: number (optional)
                └── timestamp: timestamp
```

---

*End of Documentation*
