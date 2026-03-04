const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  mobileNumber: { type: String, required: true, unique: true },
  password: { type: String, required: true, select: false },
  
  // Profile Data
  username: { type: String, unique: true, sparse: true, trim: true },
  name: { type: String, default: '' },
  bio: { type: String, default: '' },
  age: { type: String, default: '' }, // String to match controller logic
  gender: { type: String, enum: ['Male', 'Female', 'Other', ''], default: '' },
  address: { type: String, default: '' },
  emailAddress: { type: String, default: '' },
  religion: { type: String, default: '' },
  community: { type: String, default: '' },
  profilePicture: { type: String, default: '' },

  // System Flags
  profileCompleted: { type: Boolean, default: false }, // Maps to infoGathered
  accountType: { 
    type: String, 
    enum: ['Standard', 'Mentor', 'NGO', 'HolyPlace', 'Business', 'Media'], 
    default: 'Standard' 
  },
  category: { type: String, default: '' },
  
  // Auth & Notifications
  fcmTokens: [{ type: String }],
  lastLogin: { type: Date, default: Date.now },

}, { timestamps: true });

// Hash password
userSchema.pre('save', async function() {
    // 1. If password is not modified, simply return (ends the function)
    if (!this.isModified('password')) return;

    // 2. Hash the password
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    
    // 3. Do NOT call next(). The async function finishing signals "success".
});
// Compare password
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

userSchema.index({ username: 1 , mobileNumber: 1 }, { unique: true });

module.exports = mongoose.model('User', userSchema);