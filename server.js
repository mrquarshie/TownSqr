// server.js

const express = require('express');
const http = require('http');
const socketio = require('socket.io');

// --- Configuration ---
const PORT = process.env.PORT || 3000;

const app = express();
const server = http.createServer(app);

// Initialize Socket.IO with CORS enabled for the client to connect
// The '*' origin is acceptable for development purposes.
const io = socketio(server, {
    cors: {
        origin: "*", 
        methods: ["GET", "POST"]
    }
});

// --- Real-Time Connection Handling ---

io.on('connection', (socket) => {
    console.log(`[USER CONNECTED]: ${socket.id}`);

    // --- 1. Listen for new posts from any client ---
    socket.on('new_post', (payload) => {
        // The client (index.html) sends the complete payload: 
        // { sender: 'Nickname-123', content: 'The message', isSystem: false }

        // Log the activity on the server side
        if (payload.isSystem) {
             console.log(`[SYSTEM EVENT]: ${payload.content}`);
        } else {
             console.log(`[NEW POST]: @${payload.sender} posted: "${payload.content}"`);
        }

        // --- 2. Broadcast the message to ALL connected clients ---
        // io.emit sends the message to everyone, including the original sender.
        // The client-side JavaScript handles whether to display its own message or not.
        io.emit('new_post', payload);
    });

    // --- 3. Handle user disconnection ---
    socket.on('disconnect', () => {
        console.log(`[USER DISCONNECTED]: ${socket.id}`);
        
        // Optional: Broadcast a system message about the disconnect
        // (Note: The client only knows its own nickname, so we can't reliably send the nickname here)
    });
});

// --- Start the Server ---
server.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`SERVER RUNNING: Socket.IO listening on port ${PORT}`);
    console.log(`-> Now open the 'index.html' file in your browser to connect.`);
    console.log(`======================================================\n`);
});