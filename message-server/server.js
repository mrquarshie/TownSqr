// server.js

const express = require('express');
const http = require('http');
const socketio = require('socket.io');
const crypto = require('crypto'); // Used to generate unique IDs

// --- Configuration ---
const PORT = process.env.PORT || 3000;

const app = express();
const server = http.createServer(app);

// Serve static files (index.html) from the parent directory
const path = require('path');
app.use(express.static(path.join(__dirname, '..')));

// Initialize Socket.IO with CORS enabled for the client to connect
// The '*' origin is acceptable for development purposes.
const io = socketio(server, {
    cors: {
        origin: "*", 
        methods: ["GET", "POST"]
    }
});

// --- In-Memory State (Simulating a Database) ---
const posts = []; 

// --- Real-Time Connection Handling ---

io.on('connection', (socket) => {
    console.log(`[USER CONNECTED]: ${socket.id}`);

    // Optionally send existing posts to the new client (simulated history)
    socket.emit('initial_posts', posts);

    // --- 1. Listen for new posts from any client ---
    socket.on('new_post', (payload) => {
        // Assign a unique ID and timestamp to the new post
        const newPost = {
            id: crypto.randomUUID(),
            timestamp: Date.now(),
            ...payload
        };
        
        // Save the post to our in-memory "database"
        if (!newPost.isSystem) {
            posts.push(newPost);
        }

        // Log the activity on the server side
        if (newPost.isSystem) {
             console.log(`[SYSTEM EVENT]: ${newPost.content}`);
        } else {
             console.log(`[NEW POST]: @${newPost.sender} posted: "${newPost.content}" (ID: ${newPost.id})`);
        }

        // --- 2. Broadcast the message (with ID) to ALL connected clients ---
        io.emit('new_post', newPost);
    });

    // --- 3. NEW: Handle post deletion request from a client ---
    socket.on('delete_post', (postId) => {
        console.log(`[DELETE REQUEST]: ID ${postId} received.`);
        
        // Find the index of the post in the in-memory array
        const index = posts.findIndex(post => post.id === postId);

        if (index > -1) {
            // Remove the post from the array
            posts.splice(index, 1);
            
            console.log(`[POST DELETED]: ID ${postId}`);

            // Broadcast the ID of the deleted post to ALL clients
            io.emit('post_deleted', postId);
        } else {
            console.log(`[DELETE FAILED]: Post ID ${postId} not found.`);
        }
    });

    // --- 4. Handle user disconnection ---
    socket.on('disconnect', () => {
        console.log(`[USER DISCONNECTED]: ${socket.id}`);
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