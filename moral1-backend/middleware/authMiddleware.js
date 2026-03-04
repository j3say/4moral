const jwt = require('jsonwebtoken');
const User = require('../models/User');

exports.protect = async (req, res, next) => {
  let token;
  if (req.headers.authorization?.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) return res.status(401).json({ message: 'Not authorized, no token' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id || decoded.userId).select('-password');
    if (!req.user) return res.status(401).json({ message: 'User no longer exists' });
    
    next();
  } catch (err) {
    res.status(401).json({ message: 'Token invalid or expired' });
  }
};

exports.restrictTo = (...allowedRoles) => {
    return (req, res, next) => {
        if (!req.user || !allowedRoles.includes(req.user.accountType)) {
            return res.status(403).json({ 
                error: `Access Denied: Your account type (${req.user.accountType}) is not authorized.` 
            });
        }
        next();
    };