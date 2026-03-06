const User = require('../models/User');
const jwt = require('jsonwebtoken');

const signToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: '90d' });
};

// 1. REGISTER
exports.register = async (req, res, next) => {
  try {
    console.log("📝 Registration Attempt for:", req.body.mobileNumber);
    
    const newUser = await User.create({
      mobileNumber: req.body.mobileNumber,
      password: req.body.password,
      accountType: req.body.accountType || 'Standard'
    });

    console.log("✅ User Created successfully ID:", newUser._id);
    const token = signToken(newUser._id);

    res.status(201).json({ status: 'success', token, user: newUser });
  } catch (err) {
    console.error("❌ Registration Error:", err);
    next(err);
  }
};

// 2. LOGIN
exports.login = async (req, res, next) => {
  try {
    const { mobileNumber, password } = req.body;
    console.log("🔑 Login Attempt for:", mobileNumber);

    if (!mobileNumber || !password) {
      console.log("⚠️ Missing credentials");
      return res.status(400).json({ message: 'Please provide mobile and password' });
    }

    // Heavy Debug: Check if user exists
    const user = await User.findOne({ mobileNumber }).select('+password');
    
    if (!user) {
      console.log("❌ User NOT found in DB for number:", mobileNumber);
      return res.status(401).json({ status: 'fail', message: 'Invalid credentials' });
    }
    console.log("🔍 User found, comparing passwords...");

    // Heavy Debug: Check password match
    const isMatch = await user.comparePassword(password);
    console.log("⚖️ Password Match Result:", isMatch);

    if (!isMatch) {
      console.log("❌ Password did NOT match");
      return res.status(401).json({ status: 'fail', message: 'Invalid credentials' });
    }

    const token = signToken(user._id);
    console.log("🎯 Login successful, Token generated!");

    res.status(200).json({
      status: 'success',
      token,
      user
    });
  } catch (err) {
    console.error("🔥 Login Crash Error:", err);
    next(err);
  }
};