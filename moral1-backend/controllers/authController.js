const User = require('../models/User');
const jwt = require('jsonwebtoken');

const sanitizePhone = (phone) => phone.replace(/\D/g, '');
const signToken = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: '90d' });

exports.register = async (req, res, next) => {
  try {
    // const { mobileNumber, password } = req.body;
    const { password } = req.body;
    const mobileNumber = sanitizePhone(req.body.mobileNumber);
    const existingUser = await User.findOne({ mobileNumber });
    if (existingUser) {
      return res.status(400).json({ status: 'fail', message: 'Mobile number already registered' });
    }

    const dynamicUniqueId = `M_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    // const dynamicUniqueId = `MORAL1_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    const newUser = await User.create({ 
      mobileNumber, 
      password, 
      // age,
      uniqueId: dynamicUniqueId 
    });
    const token = signToken(newUser._id);
    res.status(201).json({ status: 'success', token, user: newUser });
  } catch (err) { 
    // if (err.code === 11000) {
    //   return res.status(400).json({ status: 'fail', message: 'Mobile number already registered' });
    // }
    // console.error(err); 
    next(err); 
  }
};

exports.login = async (req, res, next) => {
  try {
    const mobileNumber = sanitizePhone(req.body.mobileNumber);
    const { password } = req.body;

    const user = await User.findOne({ mobileNumber }).select('+password');
    
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ status: 'fail', message: 'Invalid credentials' });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '90d' });
    user.password = undefined; 
    res.status(200).json({ status: 'success', token, user });
  } catch (err) { next(err); }
};

exports.logout = async (req, res) => {
  // For JWT, logout is typically handled client-side by deleting the token.
  // Optionally, you could implement token blacklisting here.
  res.status(200).json({ status: 'success', message: 'Logged out successfully' });
}
// exports.login = async (req, res, next) => {
//   try {
//     const { mobileNumber, password, fcmToken } = req.body;
//     if (!mobileNumber || !password) throw new Error('Provide mobile and password');

//     const user = await User.findOne({ mobileNumber }).select('+password');
//     if (!user || !(await user.comparePassword(password))) {
//       return res.status(401).json({ status: 'fail', message: 'Invalid credentials' });
//     }

//     // Update FCM & Last Login
//     // if (fcmToken && !user.fcmTokens.includes(fcmToken)) {
//     //   user.fcmTokens.push(fcmToken);
//     // }
//     user.lastLogin = Date.now();
//     await user.save({ validateBeforeSave: false });

//     const token = signToken(user._id);
//     user.password = undefined; // Sanitize
//     res.status(200).json({ status: 'success', token, user });
//   } catch (err) { console.error(err); next(err); }
// };