import * as winston from 'winston';
import * as path from 'path';

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
const consoleFormat = winston.format.combine(
  winston.format.timestamp({ format: 'HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.colorize(),
  winston.format.printf(({ timestamp, level, message, service, ...meta }) => {
    const metaString = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : '';
    return `${timestamp} [${service || 'APP'}] ${level}: ${message}${metaString}`;
  })
);

const fileFormat = winston.format.combine(
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

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
export function createLogger(service: string): winston.Logger {
  return defaultLogger.child({ service });
}

/**
 * Gets the default logger instance
 */
export function getLogger(): winston.Logger {
  return defaultLogger;
}

/**
 * Sets the global log level
 */
export function setLogLevel(level: string): void {
  defaultLogger.level = level;
  defaultLogger.info('Log level changed', { newLevel: level });
}

/**
 * Adds a file transport to the logger
 */
export function addFileTransport(filename: string, level: string = 'info'): void {
  defaultLogger.add(new winston.transports.File({
    filename,
    level,
    format: fileFormat
  }));
}

export default defaultLogger;