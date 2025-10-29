```sql
-- Database Structure Definition for Online Ping-Pong Game

-- Table: Users
-- Stores information about registered players.
CREATE TABLE Users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for each user
    username VARCHAR(50) UNIQUE NOT NULL,               -- Unique username for login and display
    email VARCHAR(100) UNIQUE NOT NULL,                  -- Unique email for account recovery and notifications
    password_hash VARCHAR(255) NOT NULL,                 -- Hashed password for security
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the user registered
    last_login TIMESTAMP WITH TIME ZONE,                 -- Timestamp of the user's last login
    total_wins INT DEFAULT 0,                            -- Total number of matches won
    total_losses INT DEFAULT 0,                          -- Total number of matches lost
    elo_rating INT DEFAULT 1000,                         -- ELO rating for skill-based matchmaking
    avatar_id UUID NULL,                                 -- Foreign key to Avatars table (current avatar)
    paddle_id UUID NULL                                  -- Foreign key to Paddles table (current paddle)
);

-- Table: Matches
-- Stores information about individual game matches.
CREATE TABLE Matches (
    match_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for each match
    player1_id UUID NOT NULL REFERENCES Users(user_id),  -- Foreign key to Users table (player 1)
    player2_id UUID NOT NULL REFERENCES Users(user_id),  -- Foreign key to Users table (player 2)
    winner_id UUID REFERENCES Users(user_id),            -- Foreign key to Users table (the winner of the match)
    start_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- When the match started
    end_time TIMESTAMP WITH TIME ZONE,                   -- When the match ended
    duration_seconds INT,                                -- Duration of the match in seconds
    player1_score INT NOT NULL,                          -- Score of player 1 in the match
    player2_score INT NOT NULL,                          -- Score of player 2 in the match
    match_status VARCHAR(20) NOT NULL DEFAULT 'completed', -- e.g., 'completed', 'aborted', 'pending'
    elo_change_player1 INT,                              -- ELO change for player 1 after the match
    elo_change_player2 INT,                              -- ELO change for player 2 after the match
    spectator_token VARCHAR(32) NULL                     -- Optional token for spectator mode, if applicable (could be a generated UUID)
);

-- Table: MatchmakingQueue
-- Stores users currently waiting for a match.
CREATE TABLE MatchmakingQueue (
    queue_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for queue entry
    user_id UUID NOT NULL REFERENCES Users(user_id) UNIQUE, -- User waiting in the queue
    elo_rating INT NOT NULL,                             -- User's ELO rating at the time of entering the queue
    entry_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- When the user entered the queue
    preferred_ping_region VARCHAR(50) NULL               -- Optional: geographical region preference for lower latency
);

-- Table: Avatars
-- Stores definitions of available avatar cosmetic items.
CREATE TABLE Avatars (
    avatar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for each avatar item
    avatar_name VARCHAR(50) UNIQUE NOT NULL,             -- Display name of the avatar
    image_url VARCHAR(255) NOT NULL,                     -- URL or path to the avatar image asset
    rarity VARCHAR(20) NOT NULL DEFAULT 'common',        -- e.g., 'common', 'rare', 'epic', 'legendary'
    unlock_cost INT DEFAULT 0,                           -- Cost in in-game currency or condition to unlock
    is_premium BOOLEAN DEFAULT FALSE,                    -- True if it's a premium item (e.g., paid)
    description TEXT                                     -- Short description of the avatar
);

-- Table: Paddles
-- Stores definitions of available paddle cosmetic items.
CREATE TABLE Paddles (
    paddle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for each paddle item
    paddle_name VARCHAR(50) UNIQUE NOT NULL,             -- Display name of the paddle
    image_url VARCHAR(255) NOT NULL,                     -- URL or path to the paddle image asset
    rarity VARCHAR(20) NOT NULL DEFAULT 'common',        -- e.g., 'common', 'rare', 'epic', 'legendary'
    unlock_cost INT DEFAULT 0,                           -- Cost in in-game currency or condition to unlock
    is_premium BOOLEAN DEFAULT FALSE,                    -- True if it's a premium item
    description TEXT                                     -- Short description of the paddle
);

-- Table: UserInventory
-- Stores which cosmetic items (avatars, paddles) a user owns.
CREATE TABLE UserInventory (
    inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for inventory entry
    user_id UUID NOT NULL REFERENCES Users(user_id),     -- Foreign key to Users table
    item_type VARCHAR(20) NOT NULL,                      -- 'avatar' or 'paddle'
    item_id UUID NOT NULL,                               -- Foreign key to either Avatars or Paddles table
    acquired_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- When the item was acquired
    is_equipped BOOLEAN DEFAULT FALSE,                   -- True if the item is currently equipped by the user
    CONSTRAINT unique_user_item UNIQUE (user_id, item_type, item_id) -- A user can only own one of each specific item
);

-- Table: Friends
-- Stores connections between users who are friends.
CREATE TABLE Friends (
    friendship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for each friendship
    user1_id UUID NOT NULL REFERENCES Users(user_id),    -- Foreign key to Users table (initiator of friend request)
    user2_id UUID NOT NULL REFERENCES Users(user_id),    -- Foreign key to Users table (recipient of friend request)
    status VARCHAR(20) NOT NULL DEFAULT 'pending',       -- 'pending', 'accepted', 'declined', 'blocked'
    initiated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- When the friendship request was made
    accepted_at TIMESTAMP WITH TIME ZONE,                -- When the friendship was accepted
    CONSTRAINT unique_friendship UNIQUE (user1_id, user2_id), -- Ensures a unique friendship even if request is from other side
    CONSTRAINT check_different_users CHECK (user1_id != user2_id) -- A user cannot be friends with themselves
);

-- Table: GameSessions
-- Tracks active game sessions for real-time multiplayer. This table might be more for transient server-side state,
-- but a lightweight version can exist in the DB for persistence or recovery.
CREATE TABLE GameSessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for the game session
    match_id UUID REFERENCES Matches(match_id),          -- Link to the completed match record, if applicable
    player1_user_id UUID NOT NULL REFERENCES Users(user_id), -- Player 1 in the session
    player2_user_id UUID NOT NULL REFERENCES Users(user_id), -- Player 2 in the session
    server_address VARCHAR(255) NOT NULL,                -- IP address or hostname of the game server
    port INT NOT NULL,                                   -- Port number of the game server
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- When the session started
    ended_at TIMESTAMP WITH TIME ZONE,                   -- When the session ended (if disconnected/completed)
    status VARCHAR(20) NOT NULL DEFAULT 'active'         -- 'active', 'ended', 'closed'
);

-- Table: Spectators
-- Tracks users currently spectating a game session.
CREATE TABLE Spectators (
    spectator_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Unique identifier for spectator entry
    user_id UUID NOT NULL REFERENCES Users(user_id),     -- Foreign key to Users table (the spectator)
    session_id UUID NOT NULL REFERENCES GameSessions(session_id), -- Foreign key to GameSessions table
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- When the spectator joined the session
    left_at TIMESTAMP WITH TIME ZONE,                    -- When the spectator left the session
    CONSTRAINT unique_spectator_session UNIQUE (user_id, session_id) -- A user can only spectate a session once at a time
);

-- Indexes for performance
CREATE INDEX idx_users_username ON Users (username);
CREATE INDEX idx_users_email ON Users (email);
CREATE INDEX idx_users_elo_rating ON Users (elo_rating);
CREATE INDEX idx_matches_player1_id ON Matches (player1_id);
CREATE INDEX idx_matches_player2_id ON Matches (player2_id);
CREATE INDEX idx_matches_winner_id ON Matches (winner_id);
CREATE INDEX idx_matches_start_time ON Matches (start_time);
CREATE INDEX idx_matchmakingqueue_user_id ON MatchmakingQueue (user_id);
CREATE INDEX idx_matchmakingqueue_elo_rating ON MatchmakingQueue (elo_rating);
CREATE INDEX idx_userinventory_user_id ON UserInventory (user_id);
CREATE INDEX idx_userinventory_item_id_type ON UserInventory (item_id, item_type);
CREATE INDEX idx_friends_user1_id ON Friends (user1_id);
CREATE INDEX idx_friends_user2_id ON Friends (user2_id);
CREATE INDEX idx_gamesessions_player1_user_id ON GameSessions (player1_user_id);
CREATE INDEX idx_gamesessions_player2_user_id ON GameSessions (player2_user_id);
CREATE INDEX idx_spectators_user_id ON Spectators (user_id);
CREATE INDEX idx_spectators_session_id ON Spectators (session_id);

```