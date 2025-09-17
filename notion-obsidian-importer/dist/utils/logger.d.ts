import * as winston from 'winston';
declare const defaultLogger: winston.Logger;
/**
 * Creates a logger instance for a specific service/module
 */
export declare function createLogger(service: string): winston.Logger;
/**
 * Gets the default logger instance
 */
export declare function getLogger(): winston.Logger;
/**
 * Sets the global log level
 */
export declare function setLogLevel(level: string): void;
/**
 * Adds a file transport to the logger
 */
export declare function addFileTransport(filename: string, level?: string): void;
export default defaultLogger;
//# sourceMappingURL=logger.d.ts.map