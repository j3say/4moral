// Dummy authentication middleware
exports.authenticate = (req, res, next) => {
  // In production, verify JWT and set req.user
  // Using a valid 24-character hex string so MongoDB doesn't crash!
  req.user = { userId: req.headers['x-user-id'] || '150E109D213E2F0ECFD5396C' };
  next();
};