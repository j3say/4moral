// Dummy authentication middleware
exports.authenticate = (req, res, next) => {
  // In production, verify JWT and set req.user
  const userId = req.headers['x-user-id'];
  req.user = userId ? { userId } : null;
  next();
};