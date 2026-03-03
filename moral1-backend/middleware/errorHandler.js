module.exports = (err, req, res, next) => {
    console.error("❌ Error:", err.stack);

    let error = { ...err };
    error.message = err.message;

    // Handle Mongoose Duplicate Key Error (e.g., Duplicate Mobile/UniqueId)
    if (err.code === 11000) {
        const message = `Duplicate field value entered. Field: ${Object.keys(err.keyValue)}`;
        return res.status(400).json({ status: 'fail', message });
    }

    // Handle Mongoose Validation Error
    if (err.name === 'ValidationError') {
        const message = Object.values(err.errors).map(val => val.message);
        return res.status(400).json({ status: 'fail', message });
    }

    res.status(err.statusCode || 500).json({
        status: 'error',
        message: error.message || 'Internal Server Error'
    });
};