const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
    // --- Basic Details ---
    mobileNumber: { type: String, required: true, unique: true, index: true },
    uniqueId: { type: String, required: true, unique: true, index: true }, // System 2 Public ID
    username: { type: String, trim: true }, 
    name: { type: String, trim: true },
    
    // --- Auth & Security ---
    password: { 
        type: String, 
        required: [true, 'Password is required'], 
        select: false // Prevents password from returning in queries by default
    }, 
    
    // --- Set 1 Logic: Account Types ---
    accountType: { 
        type: String, 
        enum: ['Standard', 'Mentor', 'NGO', 'HolyPlace', 'Business', 'Media'], 
        default: 'Standard' 
    },
    category: { 
        type: Number, 
        enum: [1, 2, 3, 4], 
        default: 1 // 1: Fully Private, 4: Public/Searchable
    },
    
    // --- Dual Connection System ---
    // System 1: Contact-to-Contact (Private/Mutual)
    systemOneContacts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    
    // System 2: Account Following (Public/Feed)
    systemTwoFollowers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    systemTwoFollowing: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    
    // --- Privacy Flags ---
    isVerified: { type: Boolean, default: false },
    isPrivateAccount: { type: Boolean, default: true },
    
}, { timestamps: true });

// --- Middleware: Hash Password before Saving ---
userSchema.pre('save', async function() {
    // 2. If password is not modified, just return (resolves the promise)
    if (!this.isModified('password')) return;
    
    // 3. Hash the password
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    
    // 4. No need to call next(); the async function resolving signals "done"
});

// --- Method: Compare Password ---
userSchema.methods.comparePassword = async function(candidatePassword) {
    return await bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);