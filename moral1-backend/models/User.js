const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    // Basic Details
    mobileNumber: { type: String, required: true, unique: true },
    uniqueId: { type: String, required: true, unique: true }, // The ID for System 2 (Followers)
    username: { type: String, default: '' },
    name: { type: String, default: '' },
    profilePicture: { type: String, default: '' },
    bio: { type: String, default: '' },
    
    // Set 1 Logic: Account Types & Categories
    accountType: { 
        type: String, 
        enum: ['Standard', 'Mentor', 'NGO', 'HolyPlace', 'Business', 'Media'], 
        default: 'Standard' 
    },
    category: { type: Number, enum: [1, 2, 3, 4], default: 1 },
    
    // Privacy & Access (System 1 vs System 2)
    isVerified: { type: Boolean, default: false },
    isPrivateAccount: { type: Boolean, default: true }, // Default true for Standard
    contactOnlyMode: { type: Boolean, default: false }, // If true, hidden from global search
    
    // Following & Contacts References (Instead of storing full strings)
    contacts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // System 1
    followers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // System 2
    following: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    
    // Security
    blockedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);