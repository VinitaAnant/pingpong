```markdown
# Online Ping-Pong Game - API Specification

This document details the API endpoints and associated business logic for the Online Ping-Pong Game. It covers user management, matchmaking, game state, and profile management.

---

## 1. Authentication

**Description:** All authenticated endpoints will require a valid JSON Web Token (JWT) provided in the `Authorization` header as a Bearer token.

---

## 2. User Management

### 2.1. Register User

**Endpoint:** `POST /api/v1/user/register`

**Description:** Allows a new user to create an account.

**Business Logic:**
*   Requires a unique username and a strong password.
*   Upon successful registration, a new user profile is created with default stats (0 wins, 0 losses, default ranking, default avatar/paddle).
*   Returns a JWT for future authenticated requests.

**Request Body:**

```json
{
  "username": " newUser123",
  "password": "StrongPassword123!"
}
```

**Response (Success - 201 Created):**

```json
{
  "message": "User registered successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (Error - 400 Bad Request):**

```json
{
  "error": "Username already exists"
}
```

### 2.2. Login User

**Endpoint:** `POST /api/v1/user/login`

**Description:** Authenticates an existing user.

**Business Logic:**
*   Verifies provided credentials against existing user records.
*   Upon successful authentication, returns a JWT.

**Request Body:**

```json
{
  "username": "existingUser",
  "password": "UserPassword123"
}
```

**Response (Success - 200 OK):**

```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (Error - 401 Unauthorized):**

```json
{
  "error": "Invalid username or password"
}
```

---

## 3. Matchmaking System

### 3.1. Initiate Matchmaking Search

**Endpoint:** `POST /api/v1/matchmaking/search`

**Description:** Puts the authenticated user into the matchmaking queue.

**Business Logic:**
*   A user can only be in one matchmaking queue at a time.
*   The system uses skill-based matchmaking:
    *   Players are paired with others of similar ranking.
    *   If no perfect match is found, the search broadens over time (e.g., after 10 seconds, expand rank delta by 50 points; after 30 seconds, expand by 100 points, etc.).
    *   Prioritizes shortest queue times within fair rank differential.
*   Once a match is found, both players are notified, and a game session is created.

**Request Body (Optional):**

```json
{
  "matchType": "ranked" // Default is "ranked", could also be "casual" or "friend"
}
```

**Response (Success - 202 Accepted):**

```json
{
  "message": "Searching for opponent...",
  "matchmakingId": "mm_xyz123"
}
```

**Response (Match Found - 200 OK):**
*This response would typically be pushed via WebSocket or a long-polling mechanism after an initial 202.*
*For simplicity, represents the API response when a match is successfully made.*

```json
{
  "message": "Match found!",
  "gameSessionId": "game_abc789",
  "opponent": {
    "username": "OpponentUsername",
    "avatarUrl": "https://example.com/avatars/opponent.png"
  },
  "isFirstPlayer": true // Indicates if the current user is player 1 or player 2
}
```

**Response (Error - 409 Conflict):**

```json
{
  "error": "User is already in a matchmaking queue."
}
```

### 3.2. Cancel Matchmaking Search

**Endpoint:** `POST /api/v1/matchmaking/cancel`

**Description:** Removes the authenticated user from the matchmaking queue if they are currently searching.

**Business Logic:**
*   Only allows cancellation if the user is in an active matchmaking queue.

**Response (Success - 200 OK):**

```json
{
  "message": "Matchmaking search cancelled."
}
```

**Response (Error - 404 Not Found):**

```json
{
  "error": "User is not currently in a matchmaking queue."
}
```

---

## 4. Game Session (Real-time Gameplay - WebSocket)

**Description:** Game state updates and player actions will primarily use a WebSocket connection for real-time communication. The initial game session is established via HTTP, but subsequent gameplay happens over WebSockets.

### 4.1. WebSocket Connection

**Endpoint:** `ws://yourgame.com/ws/game/{gameSessionId}`

**Description:** Establishes a WebSocket connection for real-time game communication.

**Business Logic:**
*   Requires a `gameSessionId` obtained from the matchmaking system.
*   Authenticates the user via a JWT sent in the initial WebSocket connection handshake (e.g., as a query parameter or custom header).
*   Manages game state, player inputs, and physics simulation.

**WebSocket Messages (Client to Server):**

*   **`player_input`:**
    *   **Payload:** `{ "type": "move", "direction": "left" | "right", "force": 0.0-1.0 }` or `{ "type": "serve", "direction": "left" | "right", "force": 0.0-1.0 }`
    *   **Business Logic:** Processes player paddle movements and shot inputs. Validates input based on game state (e.g., can only serve if it's the player's turn to serve). Translates input into physics calculations.
*   **`player_ready`:**
    *   **Payload:** `{ "status": true }`
    *   **Business Logic:** Sent by client when the game environment is loaded and ready for play. The game starts when both players send this.
*   **`disconnect_game`:**
    *   **Payload:** `{}`
    *   **Business Logic:** Initiates a graceful disconnect from the game session. If a player disconnects mid-game, the other player is usually declared the winner (for ranked games), or given the option to leave (casual).

**WebSocket Messages (Server to Client):**

*   **`game_state_update`:**
    *   **Payload:**
        ```json
        {
          "ball": { "x": 0.5, "y": 0.5, "vx": 0.01, "vy": -0.01 },
          "player1": { "paddleX": 0.5, "score": 1, "username": "Player1" },
          "player2": { "paddleX": 0.5, "score": 0, "username": "Player2" },
          "roundStatus": "playing" | "serve_player1" | "serve_player2" | "game_over",
          "winner": null | "Player1" | "Player2",
          "physicsTick": 123456
        }
        ```
    *   **Business Logic:** This is the core game loop update, sent at a high frequency (e.g., 60 times per second). Contains all necessary information to render the game state for both clients. *Physics-Based Gameplay:* The server performs all authoritative physics calculations based on real-time inputs, ensuring consistency and preventing cheating.
*   **`player_joined`:**
    *   **Payload:** `{ "username": "OpponentUsername", "isReady": false }`
    *   **Business Logic:** Notifies clients when an opponent has connected to the game session.
*   **`player_ready_status`:**
    *   **Payload:** `{ "username": "Player2", "isReady": true }`
    *   **Business Logic:** Notifies clients about the ready status of players.
*   **`game_start_countdown`:**
    *   **Payload:** `{ "count": 3 }`
    *   **Business Logic:** Broadcasts the countdown before game start.
*   **`game_end`:**
    *   **Payload:**
        ```json
        {
          "winner": "Player1",
          "loser": "Player2",
          "score": { "Player1": 11, "Player2": 7 },
          "matchHistoryId": "mh_def456"
        }
        ```
    *   **Business Logic:** Sent when a game concludes (one player reaches 11 points with a 2-point lead). The server updates player stats and ranking after this message.
*   **`error`:**
    *   **Payload:** `{ "message": "Invalid input received" }`
    *   **Business Logic:** Informs the client of a server-side error during gameplay.

---

## 5. Player Profiles & Stats

### 5.1. Get Player Profile

**Endpoint:** `GET /api/v1/user/profile/{username}`

**Description:** Retrieves a specific user's public profile and statistics.

**Business Logic:**
*   Returns aggregated statistics.
*   `{username}` can be "me" for the authenticated user's own profile.

**Response (Success - 200 OK):**

```json
{
  "username": "exampleUser",
  "avatarUrl": "https://example.com/avatars/default.png",
  "paddleImgUrl": "https://example.com/paddles/standard.png",
  "ranking": 1250,
  "wins": 15,
  "losses": 8,
  "matchCompletionRate": 0.95, // (Wins + Losses) / Total Matches Started
  "favoritePaddleId": "standard_paddle",
  "unlockedAvatars": ["default_avatar"],
  "unlockedPaddles": ["standard_paddle", "pro_paddle"]
}
```

**Response (Error - 404 Not Found):**

```json
{
  "error": "User not found"
}
```

### 5.2. Update Player Customization

**Endpoint:** `PUT /api/v1/user/profile/customize`

**Description:** Allows an authenticated user to change their avatar and paddle.

**Business Logic:**
*   Only allows setting avatars/paddles that the user has unlocked.
*   Updates the user's active avatar and paddle.

**Request Body:**

```json
{
  "avatarId": "new_avatar_id",
  "paddleId": "fancy_paddle_id"
}
```

**Response (Success - 200 OK):**

```json
{
  "message": "Customization updated successfully",
  "currentAvatarId": "new_avatar_id",
  "currentPaddleId": "fancy_paddle_id"
}
```

**Response (Error - 400 Bad Request):**

```json
{
  "error": "Avatar ID 'new_avatar_id' is not unlocked for this user."
}
```

### 5.3. Get Match History

**Endpoint:** `GET /api/v1/user/match_history`

**Description:** Retrieves a list of matches played by the authenticated user.

**Business Logic:**
*   Paginated results to handle potentially large histories.
*   Includes outcome, opponent, score, and date for each match.

**Query Parameters:**
*   `page`: (Optional) Page number, default 1.
*   `limit`: (Optional) Items per page, default 10, max 50.

**Response (Success - 200 OK):**

```json
{
  "matches": [
    {
      "matchId": "mh_def456",
      "opponentUsername": "ProPlayerX",
      "outcome": "win",
      "score": "11-7",
      "rankingChange": "+15",
      "date": "2023-10-26T14:30:00Z"
    },
    {
      "matchId": "mh_ghi789",
      "opponentUsername": "NewbiePlayerA",
      "outcome": "loss",
      "score": "5-11",
      "rankingChange": "-8",
      "date": "2023-10-25T19:00:00Z"
    }
  ],
  "currentPage": 1,
  "totalPages": 5,
  "totalMatches": 48
}
```

---

## 6. Leaderboards

### 6.1. Get Global Leaderboard

**Endpoint:** `GET /api/v1/leaderboard/global`

**Description:** Retrieves the global top players based on ranking.

**Business Logic:**
*   Ordered by `ranking` in descending order.
*   Paginated results.

**Query Parameters:**
*   `page`: (Optional) Page number, default 1.
*   `limit`: (Optional) Items per page, default 10, max 50.

**Response (Success - 200 OK):**

```json
{
  "leaderboard": [
    {
      "rank": 1,
      "username": "EliteChamp",
      "ranking": 2500,
      "wins": 120,
      "losses": 10
    },
    {
      "rank": 2,
      "username": "PongMaster",
      "ranking": 2480,
      "wins": 115,
      "losses": 12
    }
  ],
  "currentPage": 1,
  "totalPages": 10,
  "totalPlayers": 98
}
```

---

## 7. Spectator Mode (Advanced, Future Feature)

*(Note: This section outlines future functionality based on the PRD. Initial implementation may not include this.)*

### 7.1. Get Live Matches

**Endpoint:** `GET /api/v1/spectate/live`

**Description:** Lists currently active, publicly viewable matches.

**Business Logic:**
*   Only lists matches that are explicitly marked as "spectatable" by players (optional privacy setting).
*   Includes minimal game info (players, score, match ID).

**Response (Success - 200 OK):**

```json
{
  "liveMatches": [
    {
      "gameSessionId": "game_xyz123",
      "player1": "PlayerA",
      "player2": "PlayerB",
      "score1": 5,
      "score2": 3,
      "spectators": 15
    },
    {
      "gameSessionId": "game_uvw456",
      "player1": "ProGaming",
      "player2": "NoobSlayer",
      "score1": 10,
      "score2": 9,
      "spectators": 78
    }
  ]
}
```

### 7.2. Spectate Match (WebSocket)

**Endpoint:** `ws://yourgame.com/ws/spectate/{gameSessionId}`

**Description:** Allows a user to connect as a spectator to an ongoing match.

**Business Logic:**
*   Requires a valid `gameSessionId` for an active, spectatable match.
*   Spectators receive `game_state_update` messages but cannot send `player_input` messages.
*   Latency for spectators might be slightly higher than for active players to prevent real-time advantages.

**WebSocket Messages (Server to Client - Spectator):**
*   **`game_state_update`:** (Same as game session update, but potentially with slight delay)
*   **`host_disconnected`:** `{ "message": "One of the players disconnected, match ended." }`
*   **`spectator_count_update`:** `{ "count": 16 }`

---

## 8. Monetization (Cosmetic Items - Future Feature)

*(Note: This section outlines future functionality based on the PRD. Initial implementation may not include this.)*

### 8.1. Get Available Cosmetics

**Endpoint:** `GET /api/v1/shop/cosmetics`

**Description:** Lists all available cosmetic items (avatars, paddles) for purchase or unlock.

**Business Logic:**
*   Provides details for each item, including price, type, and source (e.g., "buy", "unlock_achievement_id").

**Response (Success - 200 OK):**

```json
{
  "cosmetics": [
    {
      "id": "golden_paddle",
      "name": "Golden Power Paddle",
      "type": "paddle",
      "imageUrl": "https://example.com/cosmetics/golden_paddle.png",
      "price": { "currency": "premium_coins", "amount": 500 },
      "unlockedRequiredAchievements": []
    },
    {
      "id": "robot_avatar",
      "name": "Robot Avatar",
      "type": "avatar",
      "imageUrl": "https://example.com/cosmetics/robot_avatar.png",
      "price": { "currency": "in_game_currency", "amount": 1000 },
      "unlockedRequiredAchievements": ["reach_level_10"]
    }
  ]
}
```

---

## 9. Error Handling

**General Error Structure:**

Most error responses will follow this JSON structure with appropriate HTTP status codes.

```json
{
  "error": "Descriptive error message",
  "code": "SPECIFIC_ERROR_CODE" // Optional, for client-side programmatic handling
}
```

**Common HTTP Status Codes:**

*   **200 OK:** Request successful.
*   **201 Created:** Resource successfully created.
*   **202 Accepted:** Request accepted for processing (e.g., matchmaking).
*   **400 Bad Request:** Invalid input or payload.
*   **401 Unauthorized:** Authentication token missing or invalid.
*   **403 Forbidden:** Authenticated user lacks permission to access resource.
*   **404 Not Found:** Resource not found.
*   **409 Conflict:** Request conflicts with current server state (e.g., already in queue).
*   **500 Internal Server Error:** Generic server-side error.

---
```