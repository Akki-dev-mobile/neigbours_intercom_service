const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/onegate-logs';

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Connect to MongoDB
mongoose.connect(MONGODB_URI)
  .then(() => console.log('Connected to MongoDB'))
  .catch(err => console.error('Failed to connect to MongoDB:', err));

// Define NetworkLog Schema
const networkLogSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  url: { type: String, required: true },
  method: { type: String, required: true },
  statusCode: { type: Number },
  timestamp: { type: Date, required: true },
  duration: { type: Number, required: true },
  gateId: { type: String, required: true },
  environment: { type: String, required: true },
  error: { type: String },
  createdAt: { type: Date, default: Date.now }
});

const NetworkLog = mongoose.model('NetworkLog', networkLogSchema);

// Routes
app.get('/', (req, res) => {
  res.send('OneGate Log Server is running');
});

// Get all logs
app.get('/logs', async (req, res) => {
  try {
    const { gateId, environment, limit = 100, page = 1 } = req.query;
    
    const query = {};
    if (gateId) query.gateId = gateId;
    if (environment) query.environment = environment;
    
    const skip = (page - 1) * limit;
    
    const logs = await NetworkLog.find(query)
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .exec();
    
    const total = await NetworkLog.countDocuments(query);
    
    res.json({
      logs,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    console.error('Error fetching logs:', error);
    res.status(500).json({ error: 'Failed to fetch logs' });
  }
});

// Post logs
app.post('/logs', async (req, res) => {
  try {
    const { logs } = req.body;
    
    if (!logs || !Array.isArray(logs) || logs.length === 0) {
      return res.status(400).json({ error: 'Invalid logs data' });
    }
    
    console.log(`Received ${logs.length} logs`);
    
    // Process logs in batches to avoid overwhelming the database
    const operations = logs.map(log => ({
      updateOne: {
        filter: { id: log.id },
        update: { $set: log },
        upsert: true
      }
    }));
    
    const result = await NetworkLog.bulkWrite(operations);
    
    res.status(201).json({
      message: 'Logs saved successfully',
      inserted: result.upsertedCount,
      modified: result.modifiedCount,
      total: logs.length
    });
  } catch (error) {
    console.error('Error saving logs:', error);
    res.status(500).json({ error: 'Failed to save logs' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
