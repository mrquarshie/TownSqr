// server.js

const express = require('express');
const http = require('http');
const socketio = require('socket.io');
const crypto = require('crypto');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

// --- Configuration ---
const PORT = process.env.PORT || 3000;

const app = express();
const server = http.createServer(app);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files (index.html) from the parent directory
app.use(express.static(path.join(__dirname, '..')));

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Serve uploaded images
app.use('/uploads', express.static(uploadsDir));

// Configure multer for image uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadsDir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
    fileFilter: (req, file, cb) => {
        const allowedTypes = /jpeg|jpg|png|gif|webp/;
        const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = allowedTypes.test(file.mimetype);
        
        if (mimetype && extname) {
            return cb(null, true);
        } else {
            cb(new Error('Only image files are allowed!'));
        }
    }
});

// Initialize Socket.IO with CORS enabled
const io = socketio(server, {
    cors: {
        origin: "*", 
        methods: ["GET", "POST"]
    }
});

// --- In-Memory State (Simulating a Database) ---
const posts = []; 
const users = new Map(); // username -> { username, avatar, school, createdAt }
const socketToUser = new Map(); // socketId -> username
const userToSocket = new Map(); // username -> socketId

// Valid schools
const VALID_SCHOOLS = [
    'general',
    'central university',
    'ashesi university',
    'knust',
    'university of ghana',
    'upsa'
    
];

// --- REST API Endpoints ---

// Check username availability
app.get('/api/check-username/:username', (req, res) => {
    const username = req.params.username.toLowerCase().trim();
    
    if (!username || username.length < 3) {
        return res.json({ available: false, message: 'Username must be at least 3 characters' });
    }
    
    if (username.length > 20) {
        return res.json({ available: false, message: 'Username must be less than 20 characters' });
    }
    
    if (!/^[a-z0-9_]+$/.test(username)) {
        return res.json({ available: false, message: 'Username can only contain letters, numbers, and underscores' });
    }
    
    const available = !users.has(username);
    res.json({ available, message: available ? 'Username available' : 'Username already taken' });
});

// Register new user
app.post('/api/register', (req, res) => {
    const { username, school } = req.body;
    const normalizedUsername = username.toLowerCase().trim();
    
    if (!normalizedUsername || normalizedUsername.length < 3) {
        return res.status(400).json({ error: 'Username must be at least 3 characters' });
    }
    
    if (normalizedUsername.length > 20) {
        return res.status(400).json({ error: 'Username must be less than 20 characters' });
    }
    
    if (!/^[a-z0-9_]+$/.test(normalizedUsername)) {
        return res.status(400).json({ error: 'Username can only contain letters, numbers, and underscores' });
    }
    
    if (users.has(normalizedUsername)) {
        return res.status(400).json({ error: 'Username already taken' });
    }
    
    if (!VALID_SCHOOLS.includes(school?.toLowerCase())) {
        return res.status(400).json({ error: 'Invalid school selection' });
    }
    
    // Create user
    const user = {
        username: normalizedUsername,
        displayName: username, // Keep original casing for display
        avatar: null,
        school: school.toLowerCase(),
        createdAt: Date.now()
    };
    
    users.set(normalizedUsername, user);
    
    // Generate session token
    const token = crypto.randomBytes(32).toString('hex');
    
    res.json({
        success: true,
        token,
        user: {
            username: user.username,
            displayName: user.displayName,
            avatar: user.avatar,
            school: user.school
        }
    });
});

// Upload avatar
app.post('/api/upload-avatar', upload.single('avatar'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }
    
    const username = req.body.username;
    if (!username || !users.has(username)) {
        // Delete uploaded file if user doesn't exist
        try {
            if (req.file && req.file.path) {
                fs.unlinkSync(req.file.path);
            }
        } catch (err) {
            console.error('Error deleting uploaded file:', err);
        }
        return res.status(400).json({ error: 'Invalid user' });
    }
    
    const user = users.get(username);
    
    // Delete old avatar if exists
    if (user.avatar) {
        try {
            const oldAvatarPath = path.join(uploadsDir, path.basename(user.avatar));
            if (fs.existsSync(oldAvatarPath)) {
                fs.unlinkSync(oldAvatarPath);
            }
        } catch (err) {
            console.error('Error deleting old avatar:', err);
        }
    }
    
    user.avatar = `/uploads/${req.file.filename}`;
    users.set(username, user);
    
    res.json({
        success: true,
        avatar: user.avatar
    });
});

// Upload post image
app.post('/api/upload-post-image', upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }
    
    res.json({
        success: true,
        imageUrl: `/uploads/${req.file.filename}`
    });
}, (error, req, res, next) => {
    // Error handler for this specific route
    if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({ error: 'File too large. Maximum size is 5MB.' });
        }
        return res.status(400).json({ error: error.message });
    }
    if (error) {
        return res.status(400).json({ error: error.message || 'Upload error' });
    }
    next();
});

// Get user info
app.get('/api/user/:username', (req, res) => {
    const username = req.params.username.toLowerCase();
    const user = users.get(username);
    
    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({
        username: user.username,
        displayName: user.displayName,
        avatar: user.avatar,
        school: user.school
    });
});

// Error handling middleware for multer (must be after all routes)
app.use((error, req, res, next) => {
    if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({ error: 'File too large. Maximum size is 5MB.' });
        }
        return res.status(400).json({ error: error.message });
    }
    if (error) {
        return res.status(400).json({ error: error.message || 'Upload error' });
    }
    next();
});

// --- Socket.IO Connection Handling ---

io.on('connection', (socket) => {
    console.log(`[USER CONNECTED]: ${socket.id}`);

    // Authenticate socket connection
    socket.on('authenticate', (data) => {
        const { username } = data;
        const normalizedUsername = username?.toLowerCase();
        
        if (!normalizedUsername || !users.has(normalizedUsername)) {
            socket.emit('auth_error', { message: 'Invalid user' });
            return;
        }
        
        // Remove old socket mapping if user was already connected
        const oldSocketId = userToSocket.get(normalizedUsername);
        if (oldSocketId && oldSocketId !== socket.id) {
            socketToUser.delete(oldSocketId);
        }
        
        socketToUser.set(socket.id, normalizedUsername);
        userToSocket.set(normalizedUsername, socket.id);
        
        socket.emit('authenticated', { success: true });
        
        // Send initial posts filtered by user's school and general room
        const user = users.get(normalizedUsername);
        const userSchool = user.school;
        
        const filteredPosts = posts.filter(post => {
            return post.room === 'general' || post.room === userSchool;
        });
        
        socket.emit('initial_posts', filteredPosts);
    });

    // Handle room joining
    socket.on('join_room', (roomName) => {
        const username = socketToUser.get(socket.id);
        if (!username) return;
        
        const user = users.get(username);
        const normalizedRoom = roomName.toLowerCase();
        
        // Only allow joining general room or user's school room
        if (normalizedRoom === 'general' || normalizedRoom === user.school) {
            socket.join(normalizedRoom);
            socket.emit('room_joined', normalizedRoom);
        }
    });

    // Handle new posts
    socket.on('new_post', (payload) => {
        const username = socketToUser.get(socket.id);
        if (!username) {
            socket.emit('error', { message: 'Not authenticated' });
            return;
        }
        
        const user = users.get(username);
        if (!user) {
            socket.emit('error', { message: 'User not found' });
            return;
        }
        
        const normalizedRoom = payload.room?.toLowerCase();
        
        // Validate room access
        if (normalizedRoom !== 'general' && normalizedRoom !== user.school) {
            socket.emit('error', { message: 'You can only post to General or your school room' });
            return;
        }
        
        // Validate that post has content or image
        if (!payload.content?.trim() && !payload.imageUrl) {
            socket.emit('error', { message: 'Post must have content or an image' });
            return;
        }
        
        // Create new post
        const newPost = {
            id: crypto.randomUUID(),
            sender: username,
            displayName: user.displayName,
            avatar: user.avatar,
            content: payload.content?.trim() || '',
            imageUrl: payload.imageUrl || null,
            room: normalizedRoom,
            timestamp: Date.now(),
            replies: []
        };
        
            posts.push(newPost);
        
        console.log(`[NEW POST]: @${username} posted to ${normalizedRoom}: "${payload.content}" (ID: ${newPost.id})`);
        
        // Broadcast to users who can see this room
        if (normalizedRoom === 'general') {
            io.emit('new_post', newPost);
        } else {
            // Only send to users in the same school
            io.to(normalizedRoom).emit('new_post', newPost);
            // Also send to general room viewers
            io.to('general').emit('new_post', newPost);
        }
    });

    // Handle replies
    socket.on('reply_to_post', (payload) => {
        const username = socketToUser.get(socket.id);
        if (!username) {
            socket.emit('error', { message: 'Not authenticated' });
            return;
        }
        
        const user = users.get(username);
        const post = posts.find(p => p.id === payload.postId);
        
        if (!post) {
            socket.emit('error', { message: 'Post not found' });
            return;
        }
        
        // Check if user can see this post
        if (post.room !== 'general' && post.room !== user.school) {
            socket.emit('error', { message: 'You cannot reply to this post' });
            return;
        }
        
        const reply = {
            id: crypto.randomUUID(),
            sender: username,
            displayName: user.displayName,
            avatar: user.avatar,
            content: payload.content || '',
            imageUrl: payload.imageUrl || null,
            timestamp: Date.now()
        };
        
        post.replies = post.replies || [];
        post.replies.push(reply);
        
        console.log(`[NEW REPLY]: @${username} replied to post ${payload.postId}`);
        
        // Broadcast reply update
        if (post.room === 'general') {
            io.emit('post_replied', { postId: post.id, reply });
        } else {
            io.to(post.room).emit('post_replied', { postId: post.id, reply });
            io.to('general').emit('post_replied', { postId: post.id, reply });
        }
    });

    // Handle post deletion
    socket.on('delete_post', (data) => {
        const username = socketToUser.get(socket.id);
        if (!username) return;
        
        const { postId, room } = data;
        const postIndex = posts.findIndex(post => post.id === postId);
        
        if (postIndex === -1) return;
        
        const post = posts[postIndex];
        
        // Only allow deletion if user is the post owner
        if (post.sender !== username) {
            socket.emit('error', { message: 'You can only delete your own posts' });
            return;
        }
        
        // Delete associated image if exists
        if (post.imageUrl) {
            try {
                const imagePath = path.join(uploadsDir, path.basename(post.imageUrl));
                if (fs.existsSync(imagePath)) {
                    fs.unlinkSync(imagePath);
                }
            } catch (err) {
                console.error('Error deleting post image:', err);
            }
        }
        
        // Delete reply images if they exist
        if (post.replies && Array.isArray(post.replies)) {
            post.replies.forEach(reply => {
                if (reply.imageUrl) {
                    try {
                        const replyImagePath = path.join(uploadsDir, path.basename(reply.imageUrl));
                        if (fs.existsSync(replyImagePath)) {
                            fs.unlinkSync(replyImagePath);
                        }
                    } catch (err) {
                        console.error('Error deleting reply image:', err);
                    }
                }
            });
        }
        
        posts.splice(postIndex, 1);
        
        console.log(`[POST DELETED]: ID ${postId} by @${username}`);
        
        // Broadcast deletion
        if (post.room === 'general') {
            io.emit('post_deleted', postId);
        } else {
            io.to(post.room).emit('post_deleted', postId);
            io.to('general').emit('post_deleted', postId);
        }
    });

    // Handle user disconnection
    socket.on('disconnect', () => {
        const username = socketToUser.get(socket.id);
        if (username) {
            socketToUser.delete(socket.id);
            // Only delete socket mapping if this is the current socket for the user
            const currentSocketId = userToSocket.get(username);
            if (currentSocketId === socket.id) {
                userToSocket.delete(username);
            }
        }
        console.log(`[USER DISCONNECTED]: ${socket.id}`);
    });
});

// --- Start the Server ---
server.listen(PORT, '0.0.0.0', () => {
    const os = require('os');
    const networkInterfaces = os.networkInterfaces();
    let localIP = 'localhost';
    
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
