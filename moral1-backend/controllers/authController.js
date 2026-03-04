const User = require('../models/User');
const jwt = require('jsonwebtoken');

const signToken = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: '90d' });

exports.register = async (req, res, next) => {
  try {
    const { mobileNumber, password } = req.body;
    // Create basic user; profileCompleted defaults to false
    const newUser = await User.create({ mobileNumber, password });
    const token = signToken(newUser._id);
    res.status(201).json({ status: 'success', token, user: newUser });
  } catch (err) { console.error(err); next(err); }
};

exports.login = async (req, res, next) => {
  try {
    const { mobileNumber, password, fcmToken } = req.body;
    if (!mobileNumber || !password) throw new Error('Provide mobile and password');

    const user = await User.findOne({ mobileNumber }).select('+password');
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ status: 'fail', message: 'Invalid credentials' });
    }

    // Update FCM & Last Login
    if (fcmToken && !user.fcmTokens.includes(fcmToken)) {
      user.fcmTokens.push(fcmToken);
    }
    user.lastLogin = Date.now();
    await user.save({ validateBeforeSave: false });

    const token = signToken(user._id);
    user.password = undefined; // Sanitize
    res.status(200).json({ status: 'success', token, user });
  } catch (err) { console.error(err); next(err); }
};