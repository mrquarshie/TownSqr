// server.js

const express = require('express');
const http = require('http');
const socketio = require('socket.io');

// --- Configuration ---
const PORT = process.env.PORT || 3000;

const app = express();
const server = http.createServer(app);

// Serve static files (index.html) from the current directory
app.use(express.static(__dirname));

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
// Listen on all network interfaces (0.0.0.0) to allow phone access
server.listen(PORT, '0.0.0.0', () => {
    const os = require('os');
    const networkInterfaces = os.networkInterfaces();
    let localIP = 'localhost';
    
    // Find the first non-internal IPv4 address
    for (const interfaceName in networkInterfaces) {
        const addresses = networkInterfaces[interfaceName];
        for (const addr of addresses) {
            if (addr.family === 'IPv4' && !addr.internal) {
                localIP = addr.address;
                break;
            }
        }
        if (localIP !== 'localhost') break;
    }
    
    console.log(`\n======================================================`);
    console.log(`SERVER RUNNING: Socket.IO listening on port ${PORT}`);
    console.log(`\nAccess the app from:`);
    console.log(`  - Local: http://localhost:${PORT}`);
    console.log(`  - Network: http://${localIP}:${PORT}`);
    console.log(`\nOn your phone, use: http://${localIP}:${PORT}`);
    console.log(`======================================================\n`);
});