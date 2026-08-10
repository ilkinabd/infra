const fs = require("fs");
const { createServer: createHttpServer } = require("http");
const { createServer: createHttpsServer } = require("https");
const { Server } = require("socket.io");
const { Pool } = require("pg");
const express = require("express");
const amqp = require("amqplib");
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



const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`Socket server listening on port ${PORT}`);
});

async function startRabbitConsumer() {
  try {
    const conn = await amqp.connect(process.env.RABBITMQ_URL || "amqp://guest:guest@lobbym-rabbitmq:5672");
    const channel = await conn.createChannel();
    await channel.assertQueue("socket_events", { durable: true });
    
    console.log(`[${new Date().toISOString()}] [RabbitMQ] Connected and waiting for socket events...`);
    
    channel.consume("socket_events", (msg) => {
      if (msg !== null) {
        try {
          const data = JSON.parse(msg.content.toString());
          console.log(`[${new Date().toISOString()}] [RabbitMQ] Received event:`, JSON.stringify(data));
          
          const { to_user_id, event_type, payload } = data;
          
          if (to_user_id && userSockets.has(to_user_id)) {
            const sockets = userSockets.get(to_user_id);
            console.log(`[${new Date().toISOString()}] [RabbitMQ] Relaying event '${event_type}' to ${sockets.size} socket(s) for user ID ${to_user_id}`);
            for (const socketId of sockets) {
              io.to(socketId).emit(event_type, payload);
            }
          } else {
            console.log(`[${new Date().toISOString()}] [RabbitMQ] Recipient ID ${to_user_id} is offline`);
          }
          channel.ack(msg);
        } catch (parseErr) {
          console.error(`[${new Date().toISOString()}] [RabbitMQ] Failed to process message:`, parseErr.message);
          channel.ack(msg);
        }
      }
    });
  } catch (err) {
    console.error(`[${new Date().toISOString()}] [RabbitMQ] Consumer connection error:`, err.message);
    setTimeout(startRabbitConsumer, 5000);
  }
}

startRabbitConsumer();
