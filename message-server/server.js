// server.js

const express = require('express');
const http = require('http');
const socketio = require('socket.io');
const crypto = require('crypto'); // Used to generate unique IDs

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
server.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`SERVER RUNNING: Socket.IO listening on port ${PORT}`);
    console.log(`-> Now open the 'index.html' file in your browser to connect.`);
    console.log(`======================================================\n`);
});