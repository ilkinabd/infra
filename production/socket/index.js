const fs = require("fs");
const { createServer: createHttpServer } = require("http");
const { createServer: createHttpsServer } = require("https");
const { Server } = require("socket.io");
const { Pool } = require("pg");
const express = require("express");
require("dotenv").config();

const app = express();
app.use(express.json()); // Enable JSON body parsing for direct API requests

// HTTP Request logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] HTTP ${req.method} ${req.url}`);
  next();
});

let httpServer;
const keyPath = process.env.SSL_KEY_PATH || "/certs/key.pem";
const certPath = process.env.SSL_CERT_PATH || "/certs/cert.pem";

if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
  console.log(`[${new Date().toISOString()}] SSL certificates found at ${keyPath}, starting in HTTPS mode`);
  const options = {
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath)
  };
  httpServer = createHttpsServer(options, app);
} else {
  console.log(`[${new Date().toISOString()}] SSL certificates not found, starting in HTTP mode`);
  httpServer = createHttpServer(app);
}

const io = new Server(httpServer, {
  cors: {
    origin: "*"
  }
});

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || "postgresql://postgres:postgres@localhost:5432/lobbym"
});

pool.connect(err => {
  if (err) {
    console.error("Database connection error:", err.stack);
  } else {
    console.log("Database Connected successfully");
  }
});

const jwt = require("jsonwebtoken");
const jwtSecret = process.env.JWT_SECRET;

// Map of userId -> Set of socketId
const userSockets = new Map();

// Helper to decode JWT token and return user ID (sub claim)
function getUserIdFromToken(sToken) {
  if (!jwtSecret) {
    throw new Error("JWT_SECRET environment variable is not configured");
  }
  // Remove 'Bearer ' prefix if present
  const token = sToken.startsWith("Bearer ") ? sToken.slice(7) : sToken;
  const decoded = jwt.verify(token, jwtSecret);
  if (decoded && decoded.sub) {
    // Subject (sub) represents the user ID in tymon/jwt-auth
    return parseInt(decoded.sub, 10);
  }
  throw new Error("Invalid token payload: missing subject (sub)");
}

io.on("connection", (socket) => {
  console.log(`[${new Date().toISOString()}] Socket connected: ${socket.id}`);
  let authenticatedUserId = null;

  socket.on("connected", async (sToken) => {
    console.log(`[${new Date().toISOString()}] Socket ${socket.id} attempting authentication`);
    try {
      const userId = getUserIdFromToken(sToken);
      authenticatedUserId = userId;

      if (!userSockets.has(authenticatedUserId)) {
        userSockets.set(authenticatedUserId, new Set());
      }
      userSockets.get(authenticatedUserId).add(socket.id);
      
      console.log(`[${new Date().toISOString()}] Socket ${socket.id} successfully authenticated for user ID ${authenticatedUserId}`);
      socket.emit("authenticated", { userId: authenticatedUserId });
    } catch (err) {
      console.error(`[${new Date().toISOString()}] Authentication failed for socket ${socket.id}:`, err.message);
      socket.emit("auth_error", { message: err.message });
    }
  });

  socket.on("disconnect", () => {
    console.log(`[${new Date().toISOString()}] Socket ${socket.id} disconnected`);
    if (authenticatedUserId && userSockets.has(authenticatedUserId)) {
      const sockets = userSockets.get(authenticatedUserId);
      sockets.delete(socket.id);
      if (sockets.size === 0) {
        userSockets.delete(authenticatedUserId);
      }
      console.log(`[${new Date().toISOString()}] Socket ${socket.id} unregistered for user ID ${authenticatedUserId}`);
    }
  });
});

// POST endpoint for Laravel API to directly push notifications
app.post("/broadcast-notification", (req, res) => {
  try {
    const notification = req.body;
    console.log(`[${new Date().toISOString()}] Received notification request from API:`, JSON.stringify(notification));
    
    const recipientId = notification.to_user_id;
    if (recipientId && userSockets.has(recipientId)) {
      const sockets = userSockets.get(recipientId);
      console.log(`[${new Date().toISOString()}] Relaying notification to ${sockets.size} socket(s) for user ID ${recipientId}`);
      for (const socketId of sockets) {
        io.to(socketId).emit("notification", notification);
      }
      return res.json({ success: true, delivered: true, socketCount: sockets.size });
    } else {
      console.log(`[${new Date().toISOString()}] Recipient ID ${recipientId} is offline (not connected)`);
      return res.json({ success: true, delivered: false, reason: "User not connected" });
    }
  } catch (err) {
    console.error(`[${new Date().toISOString()}] Error broadcasting notification:`, err.message);
    return res.status(500).json({ error: err.message });
  }
});

// POST endpoint for Laravel API to directly push friend/follow requests
app.post("/broadcast-friend-request", (req, res) => {
  try {
    const friendRequest = req.body;
    console.log(`[${new Date().toISOString()}] Received friend request broadcast from API:`, JSON.stringify(friendRequest));
    
    const recipientId = friendRequest.to_user_id;
    if (recipientId && userSockets.has(recipientId)) {
      const sockets = userSockets.get(recipientId);
      console.log(`[${new Date().toISOString()}] Relaying friend request to ${sockets.size} socket(s) for user ID ${recipientId}`);
      for (const socketId of sockets) {
        io.to(socketId).emit("friend_request", friendRequest);
      }
      return res.json({ success: true, delivered: true, socketCount: sockets.size });
    } else {
      console.log(`[${new Date().toISOString()}] Recipient ID ${recipientId} is offline (not connected)`);
      return res.json({ success: true, delivered: false, reason: "User not connected" });
    }
  } catch (err) {
    console.error(`[${new Date().toISOString()}] Error broadcasting friend request:`, err.message);
    return res.status(500).json({ error: err.message });
  }
});

// POST endpoint for Laravel API to directly push conversation updates/new messages
app.post("/broadcast-conversation", (req, res) => {
  try {
    const conversation = req.body;
    console.log(`[${new Date().toISOString()}] Received conversation broadcast from API:`, JSON.stringify(conversation));
    
    const recipientId = conversation.to_user_id;
    if (recipientId && userSockets.has(recipientId)) {
      const sockets = userSockets.get(recipientId);
      console.log(`[${new Date().toISOString()}] Relaying conversation update to ${sockets.size} socket(s) for user ID ${recipientId}`);
      for (const socketId of sockets) {
        io.to(socketId).emit("conversation", conversation);
      }
      return res.json({ success: true, delivered: true, socketCount: sockets.size });
    } else {
      console.log(`[${new Date().toISOString()}] Recipient ID ${recipientId} is offline (not connected)`);
      return res.json({ success: true, delivered: false, reason: "User not connected" });
    }
  } catch (err) {
    console.error(`[${new Date().toISOString()}] Error broadcasting conversation:`, err.message);
    return res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`Socket server listening on port ${PORT}`);
});
