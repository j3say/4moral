const mongoose = require('mongoose');

const productMediaSchema = new mongoose.Schema({
  url: { type: String },
  type: { type: String, default: 'image' }
});

const productVariantSchema = new mongoose.Schema({
  name: { type: String },
  priceAdjustment: { type: Number, default: 0 },
  stockQuantity: { type: Number, default: 0 }
});

const productSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String, default: '' },
  basePrice: { type: Number, required: true },
  comparedAtPrice: { type: Number },
  mediaUrls: [productMediaSchema],
  totalStockQuantity: { type: Number, default: 0 },
  createdAt: { type: Date, default: Date.now },
  category: { type: String },
  variants: [productVariantSchema],
  userId: { type: String, required: true },
  currency: { type: String, default: 'INR' }
}, { timestamps: true });

module.exports = mongoose.model('Product', productSchema);
