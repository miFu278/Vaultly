-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Devices table
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    public_key TEXT NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);

-- Files metadata table
CREATE TABLE IF NOT EXISTS files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    r2_object_key TEXT NOT NULL,
    size BIGINT NOT NULL DEFAULT 0,
    content_type VARCHAR(100) NOT NULL DEFAULT 'application/octet-stream',
    nonce TEXT NOT NULL DEFAULT '',
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'ready', 'deleted'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_files_user_id ON files(user_id);

-- File keys table (E2EE wrapped key per authorized device)
CREATE TABLE IF NOT EXISTS file_keys (
    file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    wrapped_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (file_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_file_keys_device_id ON file_keys(device_id);

-- Pairing sessions table for pairing new devices
CREATE TABLE IF NOT EXISTS pairings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pairing_token VARCHAR(64) UNIQUE NOT NULL,
    public_key TEXT NOT NULL,
    device_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'completed', 'expired'
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pairings_token ON pairings(pairing_token);
