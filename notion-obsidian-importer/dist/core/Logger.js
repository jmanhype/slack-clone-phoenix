"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Logger = void 0;
const winston_1 = __importDefault(require("winston"));
const chalk_1 = __importDefault(require("chalk"));
class Logger {
    constructor() {
        this.logger = winston_1.default.createLogger({
            level: process.env.LOG_LEVEL || 'info',
            format: winston_1.default.format.combine(winston_1.default.format.timestamp(), winston_1.default.format.errors({ stack: true }), winston_1.default.format.json()),
            transports: [
                new winston_1.default.transports.Console({
                    format: winston_1.default.format.combine(winston_1.default.format.colorize(), winston_1.default.format.simple(), winston_1.default.format.printf(({ level, message, timestamp }) => {
                        return `${timestamp} ${level}: ${message}`;
                    }))
                })
            ]
        });
    }
    static getInstance() {
        if (!Logger.instance) {
            Logger.instance = new Logger();
        }
        return Logger.instance;
    }
    info(message, meta) {
        this.logger.info(message, meta);
    }
    warn(message, meta) {
        this.logger.warn(chalk_1.default.yellow(message), meta);
    }
    error(message, error) {
        this.logger.error(chalk_1.default.red(message), error);
    }
    debug(message, meta) {
        this.logger.debug(message, meta);
    }
    success(message) {
        this.logger.info(chalk_1.default.green(message));
    }
    progress(current, total, message) {
        const percentage = Math.round((current / total) * 100);
        this.logger.info(`[${percentage}%] ${message}`);
    }
}
exports.Logger = Logger;
exports.default = Logger.getInstance();
//# sourceMappingURL=Logger.js.map