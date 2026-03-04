// Static list replacing Firebase DB
exports.getCategories = (req, res) => {
  const { type } = req.query;
  const categories = {
    'Mentor': ['Education', 'Career', 'Life Coaching', 'Tech'],
    'NGO': ['Health', 'Environment', 'Human Rights'],
    'HolyPlace': ['Temple', 'Church', 'Mosque', 'Gurudwara'],
    'Business': ['Retail', 'Services', 'IT', 'Manufacturing'],
    'Media': ['News', 'Entertainment', 'Blog'],
    'Standard': []
  };
  
  res.status(200).json({ 
    status: 'success', 
    data: categories[type] || [] 
  });
};