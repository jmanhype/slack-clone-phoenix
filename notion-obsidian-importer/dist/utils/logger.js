"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.createLogger = createLogger;
exports.getLogger = getLogger;
exports.setLogLevel = setLogLevel;
exports.addFileTransport = addFileTransport;
const winston = __importStar(require("winston"));
const path = __importStar(require("path"));
// Define log levels
const logLevels = {
    error: 0,
    warn: 1,
    info: 2,
    debug: 3
};
// Define colors for console output
const logColors = {
    error: 'red',
    warn: 'yellow',
    info: 'green',
    debug: 'blue'
};
winston.addColors(logColors);
// Create formatters
const consoleFormat = winston.format.combine(winston.format.timestamp({ format: 'HH:mm:ss' }), winston.format.errors({ stack: true }), winston.format.colorize(), winston.format.printf(({ timestamp, level, message, service, ...meta }) => {
    const metaString = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : '';
    return `${timestamp} [${service || 'APP'}] ${level}: ${message}${metaString}`;
}));
const fileFormat = winston.format.combine(winston.format.timestamp(), winston.format.errors({ stack: true }), winston.format.json());
// Create default logger
const defaultLogger = winston.createLogger({
    levels: logLevels,
    level: process.env.LOG_LEVEL || 'info',
    format: fileFormat,
    transports: [
        new winston.transports.Console({
            format: consoleFormat
        })
    ]
});
// Add file transport if in production or if LOG_FILE is set
if (process.env.NODE_ENV === 'production' || process.env.LOG_FILE) {
    const logDir = process.env.LOG_DIR || './logs';
    const logFile = process.env.LOG_FILE || 'importer.log';
    defaultLogger.add(new winston.transports.File({
        filename: path.join(logDir, logFile),
        maxsize: 5242880, // 5MB
        maxFiles: 5,
        format: fileFormat
    }));
    // Separate error log
    defaultLogger.add(new winston.transports.File({
        filename: path.join(logDir, 'error.log'),
        level: 'error',
        maxsize: 5242880,
        maxFiles: 5,
        format: fileFormat
    }));
}
/**
 * Creates a logger instance for a specific service/module
 */
function createLogger(service) {
    return defaultLogger.child({ service });
}
/**
 * Gets the default logger instance
 */
function getLogger() {
    return defaultLogger;
}
/**
 * Sets the global log level
 */
function setLogLevel(level) {
    defaultLogger.level = level;
    defaultLogger.info('Log level changed', { newLevel: level });
}
/**
 * Adds a file transport to the logger
 */
function addFileTransport(filename, level = 'info') {
    defaultLogger.add(new winston.transports.File({
        filename,
        level,
        format: fileFormat
    }));
}
exports.default = defaultLogger;
//# sourceMappingURL=logger.js.map