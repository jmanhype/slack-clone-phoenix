import winston from 'winston';
import chalk from 'chalk';

export class Logger {
  private logger: winston.Logger;
  private static instance: Logger;

  private constructor() {
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple(),
            winston.format.printf(({ level, message, timestamp }) => {
              return `${timestamp} ${level}: ${message}`;
            })
          )
        })
      ]
    });
  }

  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  info(message: string, meta?: any): void {
    this.logger.info(message, meta);
  }

  warn(message: string, meta?: any): void {
    this.logger.warn(chalk.yellow(message), meta);
  }

  error(message: string, error?: Error | any): void {
    this.logger.error(chalk.red(message), error);
  }

  debug(message: string, meta?: any): void {
    this.logger.debug(message, meta);
  }

  success(message: string): void {
    this.logger.info(chalk.green(message));
  }

  progress(current: number, total: number, message: string): void {
    const percentage = Math.round((current / total) * 100);
    this.logger.info(`[${percentage}%] ${message}`);
  }
}

export default Logger.getInstance();